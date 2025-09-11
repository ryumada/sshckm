#!/usr/bin/env bash
set -euo pipefail

# --- Logging Functions & Colors (aligned with sshckm.sh) ---
readonly COLOR_RESET="\033[0m"
readonly COLOR_INFO="\033[0;34m"
readonly COLOR_SUCCESS="\033[0;32m"
readonly COLOR_WARN="\033[0;33m"
readonly COLOR_ERROR="\033[0;31m"

log() {
  local color="$1"; local emoji="$2"; local message="$3"
  echo -e "${color}[$(date +"%Y-%m-%d %H:%M:%S")] ${emoji} ${message}${COLOR_RESET}"
}
log_output() { echo "$1"; }
log_info() { log "${COLOR_INFO}" "ℹ️" "$1"; }
log_success() { log "${COLOR_SUCCESS}" "✅" "$1"; }
log_warn() { log "${COLOR_WARN}" "⚠️" "$1"; }
log_error() { log "${COLOR_ERROR}" "❌" "$1"; }

# Uninstall symlink for sshckm from local (~/.local/bin) or system (/usr/local/bin)

usage() {
  cat <<'USAGE'
Usage: ./uninstall.sh [--local | --system]

Removes the `sshckm` symlink from the chosen install location.

Options:
  --local    Remove ~/.local/bin/sshckm
  --system   Remove /usr/local/bin/sshckm
  -h, --help Show this help

If no option is provided, you will be prompted to choose.
USAGE
}

choice=""
case "${1:-}" in
  --local) choice="local" ;;
  --system) choice="system" ;;
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) log_error "Unknown option: $1"; usage; exit 1 ;;
esac

if [[ -z "${choice}" ]]; then
  log_info "Select uninstall target:"
  echo "  1) Local (~/.local/bin/sshckm)" >&2
  echo "  2) System (/usr/local/bin/sshckm)" >&2
  echo -n "Enter 1 or 2 (or q to cancel): " >&2
  read -r ans
  case "$ans" in
    1) choice="local" ;;
    2) choice="system" ;;
    q|Q) log_warn "Canceled."; exit 0 ;;
    *) log_error "Invalid choice."; exit 1 ;;
  esac
fi

if [[ "$choice" == "local" ]]; then
  target_link="${HOME}/.local/bin/sshckm"
  if [[ -L "$target_link" || -e "$target_link" ]]; then
    rm -f "$target_link"
    log_success "Removed: $target_link"
  else
    log_warn "Nothing to remove at $target_link"
  fi
  exit 0
fi

if [[ "$choice" == "system" ]]; then
  target_link="/usr/local/bin/sshckm"
  if rm -f "$target_link" 2>/dev/null; then
    log_success "Removed: $target_link"
  else
    log_error "Permission required to remove $target_link"
    log_output "Try: sudo rm -f '$target_link'"
    exit 1
  fi
  # Attempt to remove global completion from profile.d
  profile_file="/etc/profile.d/sshckm.sh"
  if rm -f "$profile_file" 2>/dev/null; then
    log_success "Removed: $profile_file"
  else
    log_warn "Permission required to remove global completion"
    log_output "Try: sudo rm -f '$profile_file'"
  fi
  exit 0
fi

log_error "Unexpected state."; exit 1
