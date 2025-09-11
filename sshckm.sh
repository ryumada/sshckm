#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# This ensures that the script will fail fast if any command fails.
set -e

# Resolve paths relative to this script (follow symlinks)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

# --- Configuration ---
# Path to the CSV file containing VPS details.
# Format: <name>,<ip_address>,<port>,<username>
readonly VPS_CSV_FILE="${SCRIPT_DIR}/vps_list.csv"

# Version of this script
readonly VERSION="0.1.0"

readonly ENV_FILE="${SCRIPT_DIR}/.env"
readonly SSH_IDENTITY_FILE="${HOME}/.ssh/sshfile4sshmanager"

# --- Logging Functions & Colors ---
# Define colors for log messages
readonly COLOR_RESET="\033[0m"
readonly COLOR_INFO="\033[0;34m"
readonly COLOR_SUCCESS="\033[0;32m"
readonly COLOR_WARN="\033[0;33m"
readonly COLOR_ERROR="\033[0;31m"

# Function to log messages with a specific color and emoji
log() {
    local color="$1"
    local emoji="$2"
    local message="$3"
    echo -e "${color}[$(date +"%Y-%m-%d %H:%M:%S")] ${emoji} ${message}${COLOR_RESET}"
}

log_output() { echo "$1"; }
log_info() { log "${COLOR_INFO}" "ℹ️" "$1"; }
log_success() { log "${COLOR_SUCCESS}" "✅" "$1"; }
log_warn() { log "${COLOR_WARN}" "⚠️" "$1"; }
log_error() { log "${COLOR_ERROR}" "❌" "$1"; }
# ------------------------------------

function show_usage() {
    local exit_code="${1:-1}"
    log_output "Usage: $0 [options] <action> [args]"
    log_output ""
    log_output "Actions:"
    log_output "  connect <vps_name>    Connect to a VPS via SSH."
    log_output "  removekey <vps_name>  Remove SSH key for a single VPS."
    log_output "  removeallkeys         Remove SSH keys for all VPS."
    log_output "  rotatekey <vps_name>  Rotate SSH keys on a VPS."
    log_output "  rotateallkeys         Rotate SSH keys on all VPS."
    log_output ""
    log_output "Options:"
    log_output "  -h, --help            Show this help and exit."
    log_output "  -v, --version         Show version and exit."
    log_output "  --completion          Output bash completion script."
    log_output "  --script-path         Print the resolved script file path."
    log_output "  --script-dir          Print the resolved script directory."
    log_output "  --config-paths        Print paths for .env and vps_list.csv."
    log_output ""
    log_output "Configuration:"
    log_output "  - Files are loaded from: ${SCRIPT_DIR}"
    log_output "  - CSV format: header line + rows: name,ip,port,username"
    log_output "  - See .env.example and vps_list.csv.example for templates"
    log_output ""
    log_output "Completion:"
    log_output "  - Enable for current session: source <(sshckm --completion)"
    log_output "  - Persist for new sessions: add the above to ~/.bashrc"
    log_output ""
    log_output "Tips:"
    log_output "  - Check locations: $0 --config-paths | --script-dir | --script-path"
    log_output "  - 'removekey' and 'removeallkeys' confirm before deleting keys"
    log_output "  - 'rotatekey' may prompt for your VPS password to copy the key"
    log_output ""
    log_output "Examples:"
    log_output "  $0 connect my_server1"
    log_output "  $0 removekey my_server1"
    log_output "  $0 removeallkeys"
    log_output "  $0 rotatekey my_server1"
    log_output "  $0 rotateallkeys"
    exit "$exit_code"
}

function show_version() {
    log_output "sshckm ${VERSION}"
}

# Internal helper: list supported actions (one per line)
function __list_actions() {
    printf "%s\n" \
        "connect" \
        "removekey" \
        "removeallkeys" \
        "rotatekey" \
        "rotateallkeys"
}

# Internal helper: list VPS names from CSV (one per line)
function __list_vps_names() {
    local csv
    if [[ -f "${VPS_CSV_FILE}" ]]; then
        csv="${VPS_CSV_FILE}"
    else
        # Fallback to XDG config path if installed elsewhere
        local cfg_home="${XDG_CONFIG_HOME:-$HOME/.config}"
        if [[ -f "${cfg_home}/sshckm/vps_list.csv" ]]; then
            csv="${cfg_home}/sshckm/vps_list.csv"
        fi
    fi

    if [[ -n "$csv" && -f "$csv" ]]; then
        # Skip header, take first column, trim whitespace, skip empties
        tail -n +2 "$csv" | \
            cut -d',' -f1 | \
            sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
            grep -v '^[[:space:]]*$' || true
    fi
}

# Output a bash completion snippet for this command
function __print_completion() {
    cat <<'EOF'
_sshckm_completion() {
    local cur prev words cword cmd
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd="${COMP_WORDS[0]}"

    # First argument: action or option
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        local items
        # Include options as first-arg completions; use safe printf
        items="$($cmd --actions 2>/dev/null; printf '%s\n' --help -h --version -v --completion --script-path --script-dir --config-paths)"
        COMPREPLY=( $(compgen -W "$items" -- "$cur") )
        return 0
    fi

    # Second argument: VPS name for actions that require it
    local action="${COMP_WORDS[1]}"
    case "$action" in
        connect|removekey|rotatekey)
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                local names
                names="$($cmd --vps-names 2>/dev/null)"
                COMPREPLY=( $(compgen -W "$names" -- "$cur") )
                return 0
            fi
            ;;
    esac

    return 0
}

# Register completion for common names
complete -F _sshckm_completion sshckm
complete -F _sshckm_completion sshckm.sh
EOF
}

function show_script_path() {
    echo "${SOURCE}"
}

function show_script_dir() {
    echo "${SCRIPT_DIR}"
}

function show_config_paths() {
    local env_path="${ENV_FILE}"
    local csv_path="${VPS_CSV_FILE}"
    if [[ -f "$env_path" ]]; then
        echo ".env: ${env_path} (exists)"
    else
        echo ".env: ${env_path} (missing)"
    fi
    if [[ -f "$csv_path" ]]; then
        echo "vps_list.csv: ${csv_path} (exists)"
    else
        echo "vps_list.csv: ${csv_path} (missing)"
    fi
}

function connect_vps() {
    local vps_name="$1"
    local SSH_FILE_FOR_VPS="${SSH_IDENTITY_FILE}-${vps_name}"

    if [[ ! -f "$SSH_FILE_FOR_VPS" ]]; then
        log_error "The key file ($SSH_FILE_FOR_VPS) to SSH to ${COLOR_RESET}${vps_name}${COLOR_ERROR} is not found. Please create it by running 'rotatekey' action."
        log_warn "You will be prompted your vps password in order to update the SSH key."
        echo
        exit 1
    fi

    local details errfile
    errfile=$(mktemp)
    if ! details=$(get_vps_details "${vps_name}" 2>"$errfile"); then
        log_error "$(cat "$errfile")"
        echo
        rm -f "$errfile"
        exit 1
    fi
    rm -f "$errfile"

    local ip port username
    read -r ip port username <<< "${details}"
    local remote_host="${username}@${ip}"

    log_info "Attempting to connect to ${COLOR_RESET}${remote_host}${COLOR_INFO} on port ${port}..."

    ssh -i "$SSH_FILE_FOR_VPS" -p "${port}" "${remote_host}"

    local status="$?"

    if [ $status -eq 0 ]; then
        log_success "Connection successfully."
    else
        log_error "Connection failed. Please check your credentials or network."
        echo
        exit 1
    fi
}

function get_vps_details() {
    # _inherit = connect_vps()
    local vps_name="$1"

    local line
    # Avoid exiting the whole script under `set -e` when grep finds no match
    if ! line=$(grep -E "^[[:space:]]*${vps_name}[[:space:]]*,.*" "$VPS_CSV_FILE"); then
        echo "VPS details not found in the vps_list.csv file." >&2
        return 1
    fi

    local ip port username

    ip=$(echo "$line" | cut -d',' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    port=$(echo "$line" | cut -d',' -f3 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    username=$(echo "$line" | cut -d',' -f4 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    echo "${ip} ${port} ${username}"
    return 0
}

function remove_key() {
    local vps_name="$1"
    local SSH_FILE_FOR_VPS="${SSH_IDENTITY_FILE}-${vps_name}"

    if [[ ! -f "${SSH_FILE_FOR_VPS}" ]]; then
        log_warn "Key file for ${COLOR_RESET}${vps_name}${COLOR_WARN} not found at ${SSH_FILE_FOR_VPS}. Skipping removal."
        return 0
    fi

    local details errfile
    errfile="$(mktemp)"
    if ! details=$(get_vps_details "${vps_name}" 2>"$errfile"); then
        log_error "$(cat "$errfile")"
        echo
        rm -f "$errfile"
        return 1
    fi
    rm -f "$errfile"

    local ip port username
    read -r ip port username <<< "${details}"
    local remote_host="${username}@${ip}"

    log_warn "WARNING: This will permanently delete the SSH key for ${COLOR_RESET}${vps_name}${COLOR_WARN} from your local machine AND from the remote server's authorized_keys file."
    log_output "Are you sure you want to proceed? (y/n))"
    read -rp ": " response < /dev/tty
    case "$response" in
        [yY][eE][sS]|[yY])
            local PUBLIC_KEY
            if [[ -f "${SSH_FILE_FOR_VPS}.pub" ]]; then
                PUBLIC_KEY="$(cat "${SSH_FILE_FOR_VPS}.pub")"
                log_info "Removing the public key from ${COLOR_RESET}${vps_name}${COLOR_INFO}'s authorized keys file..."
                if ! ssh -p "${port}" -i "${SSH_FILE_FOR_VPS}" "${remote_host}" \
                    '
                        read -r PUBLIC_KEY
                        grep -vF -- "${PUBLIC_KEY}" "$HOME/.ssh/authorized_keys" > "$HOME/.ssh/authorized_keys.tmp" &&
                        mv "$HOME/.ssh/authorized_keys.tmp" "$HOME/.ssh/authorized_keys"
                    ' <<< "${PUBLIC_KEY}"; then
                    log_error "Failed to remove the public key from ${COLOR_RESET}${vps_name}${COLOR_ERROR}. This key may still be active on the VPS. Please remove it manually in ~/.ssh/authorized_keys file."
                else
                    log_success "Public key successfully removed from ${COLOR_RESET}${vps_name}${COLOR_SUCCESS}."
                fi
            else
                log_warn "Public key for ${COLOR_RESET}${vps_name}${COLOR_WARN} not found. Skipping remote public key removal."
            fi

            log_info "Removing local key files for ${COLOR_RESET}${vps_name}${COLOR_INFO}..."
            rm -f "${SSH_FILE_FOR_VPS}"
            rm -f "${SSH_FILE_FOR_VPS}.pub"
            if ! rm -f "${SSH_FILE_FOR_VPS}.bak"; then
                log_error "The private bak key file (${SSH_FILE_FOR_VPS}.bak) is not found on the Local."
            fi
            if ! rm -f "${SSH_FILE_FOR_VPS}.pub.bak"; then
                log_error "The public bak key file (${SSH_FILE_FOR_VPS}.pub.bak) is not found on the Local."
            fi
            log_success "Local key files for ${COLOR_RESET}${vps_name}${COLOR_SUCCESS} successfully removed."
            ;;
        *)
            log_error "You didn't type the exact prompt. Key removal aborted."
            ;;
    esac

    return 0
}

function remove_all_keys() {
    log_warn "This will attempt to permanently delete ALL SSH keys created by this utility from your local machine AND from the remote VPSes' authorized_keys."
    log_output "Are you sure you want to proceed? (y/n))"
    read -rp ": " response
    case "$response" in
        [yY][eE][sS]|[yY])
            log_info "Starting removal of all keys..."
            while IFS=',' read -r name ip port username; do
                name=$(echo "${name}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [[ -n "${name}" ]]; then
                    remove_key "${name}" || log_error "Failed to remove key for ${COLOR_RESET}${name}${COLOR_ERROR}."
                fi
            done < <(tail -n +2 "${VPS_CSV_FILE}")
            ;;
        *)
            log_info "Key removal aborted."
            ;;
    esac

    return 0
}

function require_exact_args() {
    local expected="$1"
    local action="$2"
    shift 2
    if [ "$#" -lt "$expected" ]; then
        log_error "Missing required argument <vps_name> for '${action}' action."
        log_output ""
        show_usage
    elif [ "$#" -gt "$expected" ]; then
        log_error "Too many argument for '${action}' action."
        log_output ""
        show_usage
    fi
}

function rotate_key() {
    local vps_name="$1"
    local SSH_FILE_FOR_VPS="${SSH_IDENTITY_FILE}-${vps_name}"

    local details errfile
    errfile="$(mktemp)"
    if ! details=$(get_vps_details "${vps_name}" 2>"$errfile"); then
        log_error "$(cat "$errfile")"
        echo
        rm -f "$errfile"
        return 1
    fi
    rm -f "$errfile"

    local ip port username
    read -r ip port username <<< "${details}"
    local remote_host="${username}@${ip}"

    if [[ -f "$SSH_FILE_FOR_VPS" ]]; then
        log_warn "Existing SSH identity file for ${COLOR_RESET}${vps_name}${COLOR_WARN} found. Backing it up $SSH_FILE_FOR_VPS.bak..."
        mv "$SSH_FILE_FOR_VPS" "$SSH_FILE_FOR_VPS.bak"
        mv "$SSH_FILE_FOR_VPS.pub" "$SSH_FILE_FOR_VPS.pub.bak"
        log_success "Existing SSH identity file has been backed up."
    else
        log_success "There are no current SSH identity file. We can continue to generate the new SSH key."
    fi

    log_info "Generating a new SSH key pair for ${COLOR_RESET}${vps_name}${COLOR_INFO} named '$SSH_FILE_FOR_VPS'..."
    if ! ssh-keygen -t ed25519 -f "$SSH_FILE_FOR_VPS" -C "ssh-manager-key for ${vps_name}; Created by ${HOSTNAME}" -q -N ""; then
        log_error "Failed to generate a new key pair. Aborting."
        return 1
    fi
    log_success "The new SSH key pair has been generated successfully."

    log_info "Copying the new public key to ${COLOR_RESET}${remote_host}${COLOR_INFO} on port ${port}..."
    if ! ssh-copy-id -f -p "${port}" -i "${SSH_FILE_FOR_VPS}.pub" -o "IdentityFile=${SSH_FILE_FOR_VPS}.bak" -o "StrictHostKeyChecking=accept-new" "${remote_host}" < /dev/tty; then
        log_error "Failed to copy the new public key to ${COLOR_RESET}${vps_name}${COLOR_ERROR}. Please check your credentials."
        return 1
    fi
    log_success "The new public key file has been copied successfully to ${COLOR_RESET}${vps_name}${COLOR_SUCCESS}."

    log_info "Testing the new key on ${COLOR_RESET}${vps_name}${COLOR_INFO}..."
    if ! ssh -p "${port}" -i "${SSH_FILE_FOR_VPS}" "${remote_host}" "echo 'Hi, from ${vps_name}. 😁'"; then
        log_error "Test with new key failed on ${COLOR_RESET}${vps_name}${COLOR_ERROR}. Aborting the rotation to prevent lockout."
        return 1
    fi

    if [[ -f "$SSH_FILE_FOR_VPS.bak" ]]; then
        log_info "Removing the old key from ${COLOR_RESET}${vps_name}${COLOR_INFO}..."

        local PUBLIC_KEY
        PUBLIC_KEY="$(cat "${SSH_FILE_FOR_VPS}.pub.bak")"
        if ! ssh -p "${port}" -i "${SSH_FILE_FOR_VPS}" "${remote_host}" \
            '
                read -r PUBLIC_KEY
                grep -vF -- "${PUBLIC_KEY}" "$HOME/.ssh/authorized_keys" > "$HOME/.ssh/authorized_keys.tmp" &&
                mv "$HOME/.ssh/authorized_keys.tmp" "$HOME/.ssh/authorized_keys"
            ' <<< "${PUBLIC_KEY}"; then
            log_error "Failed to remove the old key from ${COLOR_RESET}${vps_name}${COLOR_ERROR}. The public key may be not registered in autorized_keys file inside ${vps_name}."
        else
            log_success "The old public key successfully removed from ${COLOR_RESET}${vps_name}${COLOR_SUCCESS}."
        fi
    else
        log_warn "Could not find the old key. Skipping public key removal from ${COLOR_RESET}${vps_name}${COLOR_WARN}."
    fi

    return 0
}

function rotate_all_keys() {
    while IFS=',' read -r name ip port username; do
        name=$(echo "${name}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "${name}" ]]; then
            log_info "Rotating key for: ${COLOR_RESET}${name}${COLOR_INFO}"
            rotate_key "${name}" </dev/null || log_error "Failed to rotate key for ${COLOR_RESET}${name}${COLOR_ERROR}."
        fi
    done < <(tail -n +2 "${VPS_CSV_FILE}")
}

function main() {
    # Global options (handled before any validation)
    case "${1:-}" in
        -h|--help)
            show_usage 0 ;;
        -v|--version)
            show_version; exit 0 ;;
        --actions)
            __list_actions; exit 0 ;;
        --vps-names)
            __list_vps_names; exit 0 ;;
        --completion)
            __print_completion; exit 0 ;;
        --script-path)
            show_script_path; exit 0 ;;
        --script-dir)
            show_script_dir; exit 0 ;;
        --config-paths)
            show_config_paths; exit 0 ;;
    esac

    if [ "$#" -lt 1 ]; then
        show_usage 1
    fi

    if [[ ! -f "$VPS_CSV_FILE" ]]; then
        log_error "vps_list.csv file is not found. Please copy it from the example file."
        echo
        exit 1
    fi

    if [[ ! -f "$ENV_FILE" ]]; then
        log_error ".env file is not found. Please copy it from the example file, then edit its value."
        echo
        exit 1
    fi

    # log_info "Validate .env file content"
    if grep -q "enter_" "$ENV_FILE"; then
        log_error "Your .env file still contains default placeholder values."
        grep "enter_" "$ENV_FILE" | while read -r line ; do
        log_error "  - Please configure: ${line}"
        done
        log_error "Exiting. Please update the .env file and re-run the script again."
        exit 1
    fi
    # log_success "Validate .env file content completed"

    source "${ENV_FILE}";

    local action="$1"
    shift

    case "${action}" in
        connect)
            require_exact_args 1 "${action}" "$@"
            connect_vps "$@"
            ;;
        removekey)
            require_exact_args 1 "${action}" "$@"
            remove_key "$@"
            ;;
        removeallkeys)
            remove_all_keys
            ;;
        rotatekey)
            require_exact_args 1 "${action}" "$@"
            rotate_key "$@"
            ;;
        rotateallkeys)
            rotate_all_keys
            ;;
        *)
            log_error "Invalid action: '${action}'."
            log_output ""
            show_usage 1
            ;;
    esac
}

main "$@"
