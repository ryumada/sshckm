#!/usr/bin/env bash
set -euo pipefail

# Install symlink for sshckm: local (~/.local/bin) or system (/usr/local/bin)

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--local | --system]

Installs a symlink named `sshckm` pointing to the repo's sshckm.sh.

Options:
  --local   Install into ~/.local/bin (no sudo required)
  --system  Install into /usr/local/bin (may require sudo)
  -h, --help  Show this help

If no option is provided, you will be prompted to choose.
USAGE
}

# Warn user if required config files are missing or uninitialized
warn_config_state() {
  local env_path="${REPO_DIR}/.env"
  local csv_path="${REPO_DIR}/vps_list.csv"
  local had_warn=0

  if [[ ! -f "$env_path" ]]; then
    echo "WARNING: Missing .env at $env_path" >&2
    echo "  - Copy from example: cp '${REPO_DIR}/.env.example' '$env_path' and edit values" >&2
    had_warn=1
  else
    if grep -q 'enter_' "$env_path" 2>/dev/null; then
      echo "WARNING: .env contains placeholder values (enter_...). Edit before use." >&2
      had_warn=1
    fi
  fi

  if [[ ! -f "$csv_path" ]]; then
    echo "WARNING: Missing vps_list.csv at $csv_path" >&2
    echo "  - Copy from example: cp '${REPO_DIR}/vps_list.csv.example' '$csv_path' and add your hosts (keep the header)" >&2
    had_warn=1
  else
    # Light header sanity check (header is required because the script uses tail -n +2)
    local first
    first="$(head -n1 "$csv_path" 2>/dev/null || true)"
    if ! printf '%s' "$first" | grep -qiE '\bip\b' || ! printf '%s' "$first" | grep -qiE '\bport\b'; then
      echo "WARNING: vps_list.csv first line doesn't look like a header." >&2
      echo "  - Expected header: vps_name,ip,port,username" >&2
      had_warn=1
    fi
  fi

  if [[ "$had_warn" -eq 1 ]]; then
    echo "Tip: verify paths with 'sshckm --config-paths' and list names with 'sshckm --vps-names'" >&2
  fi
}

# Resolve repo dir for sshckm.sh (follow symlinks)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
REPO_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
SCRIPT_FILE="${REPO_DIR}/sshckm.sh"

if [[ ! -f "$SCRIPT_FILE" ]]; then
  echo "Error: sshckm.sh not found at $SCRIPT_FILE" >&2
  exit 1
fi
chmod +x "$SCRIPT_FILE" || true

choice=""
case "${1:-}" in
  --local) choice="local" ;;
  --system) choice="system" ;;
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
esac

if [[ -z "$choice" ]]; then
  echo "Select installation target:" >&2
  echo "  1) Local (~/.local/bin/sshckm)" >&2
  echo "  2) System (/usr/local/bin/sshckm)" >&2
  echo -n "Enter 1 or 2 (or q to cancel): " >&2
  read -r ans
  case "$ans" in
    1) choice="local" ;;
    2) choice="system" ;;
    q|Q) echo "Canceled."; exit 0 ;;
    *) echo "Invalid choice." >&2; exit 1 ;;
  esac
fi

if [[ "$choice" == "local" ]]; then
  target_dir="${HOME}/.local/bin"
  target_link="${target_dir}/sshckm"
  mkdir -p "$target_dir"
  ln -sfn "$SCRIPT_FILE" "$target_link"
  echo "Installed local symlink: $target_link -> $SCRIPT_FILE"
  warn_config_state
  case ":${PATH}:" in
    *":${target_dir}:"*) ;;
    *) echo "Note: $target_dir is not in PATH. Add to your shell rc." ;;
  esac
  echo "To enable bash completion for this session: source <(sshckm --completion)"
  # Offer to add completion to ~/.bashrc (local install)
  rc_file="${HOME}/.bashrc"
  if [[ -w "$rc_file" ]]; then
    if ! grep -qsF "source <(sshckm --completion)" "$rc_file"; then
      if [[ -t 1 ]]; then
        echo -n "Add sshckm bash completion to ~/.bashrc for future sessions? [y/N]: "
        read -r ans
        if [[ "$ans" =~ ^([yY]|[yY][eE][sS])$ ]]; then
          {
            echo ""
            echo "# sshckm completion (added by sshckm install.sh BEGIN)"
            echo "if command -v sshckm >/dev/null 2>&1; then"
            echo "  source <(sshckm --completion)"
            echo "fi"
            echo "# sshckm completion (added by sshckm install.sh END)"
          } >> "$rc_file"
          echo "Appended completion block to $rc_file"
        else
          echo "Skipped updating $rc_file. You can add: source <(sshckm --completion)"
        fi
      fi
    fi
  fi
  exit 0
fi

if [[ "$choice" == "system" ]]; then
  target_dir="/usr/local/bin"
  target_link="${target_dir}/sshckm"
  if ln -sfn "$SCRIPT_FILE" "$target_link" 2>/dev/null; then
    echo "Installed system symlink: $target_link -> $SCRIPT_FILE"
  else
    echo "Permission required. Try: sudo ln -sfn '$SCRIPT_FILE' '$target_link'" >&2
    exit 1
  fi
  warn_config_state
  echo "To enable bash completion for this session: source <(sshckm --completion)"
  # Offer to install global completion in /etc/profile.d (system-wide)
  if [[ -t 1 ]]; then
    echo -n "Install global bash completion in /etc/profile.d/sshckm.sh? [y/N]: "
    read -r ans
    if [[ "$ans" =~ ^([yY]|[yY][eE][sS])$ ]]; then
      dest="/etc/profile.d/sshckm.sh"
      tmp="$(mktemp)"
      {
        echo "# sshckm bash completion (installed by sshckm install.sh)"
        echo "# Only for bash shells"
        echo "if [ -n \"$BASH_VERSION\" ]; then"
        echo "  if command -v sshckm >/dev/null 2>&1; then"
        echo "    source <(sshckm --completion)"
        echo "  fi"
        echo "fi"
      } > "$tmp"
      if install -m 0644 "$tmp" "$dest" 2>/dev/null; then
        echo "Installed global completion: $dest"
      else
        echo "Permission required. Run this to install completion globally:" >&2
        echo "  sudo install -m 0644 '$tmp' '$dest'" >&2
      fi
      rm -f "$tmp"
    fi
  fi
  exit 0
fi

echo "Unexpected state." >&2; exit 1
