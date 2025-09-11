#!/usr/bin/env bash
set -euo pipefail

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
  *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
esac

if [[ -z "${choice}" ]]; then
  echo "Select uninstall target:" >&2
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
  target_link="${HOME}/.local/bin/sshckm"
  if [[ -L "$target_link" || -e "$target_link" ]]; then
    rm -f "$target_link"
    echo "Removed: $target_link"
  else
    echo "Nothing to remove at $target_link"
  fi
  exit 0
fi

if [[ "$choice" == "system" ]]; then
  target_link="/usr/local/bin/sshckm"
  if rm -f "$target_link" 2>/dev/null; then
    echo "Removed: $target_link"
  else
    echo "Permission required. Try: sudo rm -f '$target_link'" >&2
    exit 1
  fi
  exit 0
fi

echo "Unexpected state." >&2; exit 1
