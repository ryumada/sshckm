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
- `vps_list.csv`: host inventory. Format: `name,ip,port,username`
- `.env`: required configuration (copy from `.env.example` and edit)

**Install (user local)**
- Ensure executable: `chmod +x sshckm.sh`
- Add a symlinked command:
  - `mkdir -p ~/.local/bin`
  - `ln -sf "$(pwd)/sshckm.sh" ~/.local/bin/sshckm`
- Ensure `~/.local/bin` is on your `PATH`.

Use it:
- `sshckm connect my_server`

**Install (system-wide, requires sudo)**
- `sudo install -m 0755 sshckm.sh /usr/local/bin/sshckm`

**Path behavior**
- The script resolves `vps_list.csv` and `.env` relative to the script location (via `SCRIPT_DIR`), so it works from any directory.

**Setup**
- Copy examples and edit values:
  - `cp .env.example .env` and update all placeholders
  - `cp vps_list.csv.example vps_list.csv` and add your hosts

**Usage**
- Connect: `sshckm connect <name>`
- Rotate key: `sshckm rotatekey <name>`
- Remove key: `sshckm removekey <name>`
- Rotate all: `sshckm rotateallkeys`
- Remove all: `sshckm removeallkeys`

---

Copyright © 2025 ryumada. All Rights Reserved.

Licensed under the MIT license. See `LICENSE`.
