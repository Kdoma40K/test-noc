#!/usr/bin/env bash
# One-time install of the remote-ricing kit. Run from anywhere in the repo.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.local/bin ~/.config/systemd/user
install -m755 "$here/claude-rc.sh" "$here/rice-apply.sh" "$here/pc-shot" ~/.local/bin/
install -m644 "$here/claude-rc.service" ~/.config/systemd/user/
systemctl --user daemon-reload
echo "Installed. Next: sudo loginctl enable-linger $USER && systemctl --user enable --now claude-rc"
