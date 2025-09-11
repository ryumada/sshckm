# SSHCKM (SSH Connection & Key Manager)
> This README.md is created by AI.

Minimal SSH connection manager that reads a CSV inventory and helps you connect, rotate keys, and clean up keys per host.

Note: The script is currently named `sshckm.sh`. Expose it as the `sshckm` command via a symlink or system-wide install.

**Features**
- Connect to a named host from a CSV inventory
- Rotate per-host SSH keys safely (backup → copy-id → test → cleanup)
- Remove a host key locally and from remote `authorized_keys`
- Bulk rotate/remove across all hosts

**Prerequisites**
- `ssh`, `ssh-keygen`, `ssh-copy-id`
- Bash (tested with bash)

**Files**
- `vps_list.csv`: host inventory. Header required. Rows format: `name,ip,port,username`
- `.env`: required configuration (copy from `.env.example` and edit)

**Install (user local)**
- Ensure executable: `chmod +x sshckm.sh`
- Use the helper script to install locally (recommended):
  - `./install.sh --local`
- Or interactively choose local/system: `./install.sh`
- Ensure `~/.local/bin` is on your `PATH`.

Use it:
- `sshckm connect my_server`

**Install (system-wide, symlink, may require sudo)**
- `./install.sh --system` (if permission denied, rerun with sudo)
- Optional: Install global bash completion to all users via `/etc/profile.d/sshckm.sh` (prompted by installer). This requires root.

**Uninstall**
- Local: `./uninstall.sh --local`
- System: `./uninstall.sh --system`
  - Also removes `/etc/profile.d/sshckm.sh` if present (requires root or will print the sudo command)

**Enable Bash completion**
- One-time for current session: `source <(sshckm --completion)`
- Persist for new sessions (bash): add this to `~/.bashrc`:
  - `if command -v sshckm >/dev/null 2>&1; then source <(sshckm --completion); fi`
- The installer will offer to append this line to your `~/.bashrc` automatically.
 - System-wide alternative (all users): installer can create `/etc/profile.d/sshckm.sh` that sources completion when `sshckm` is present.

**Utility flags**
- `--script-path`: prints the resolved script file path (follows symlinks)
- `--script-dir`: prints the resolved script directory
- `--config-paths`: prints where `.env` and `vps_list.csv` are looked up

**Path behavior**
- The script resolves `vps_list.csv` and `.env` relative to the script location (via `SCRIPT_DIR`), so it works from any directory.

**Setup**
- Copy examples and edit values:
  - `cp .env.example .env` and update all placeholders
  - `cp vps_list.csv.example vps_list.csv` and add your hosts (keep the header)

**Usage**
- Connect: `sshckm connect <name>`
- Rotate key: `sshckm rotatekey <name>`
- Remove key: `sshckm removekey <name>`
- Rotate all: `sshckm rotateallkeys`
- Remove all: `sshckm removeallkeys`

---

Copyright © 2025 ryumada. All Rights Reserved.

Licensed under the MIT license. See [LICENSE](LICENSE).
