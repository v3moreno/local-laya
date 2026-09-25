#!/usr/bin/env bash
# Install the laya daemon systemd user units.
#   ./install.sh           install units
#   systemctl --user start laya-cpu    (CPU mode, port 8123)
#   systemctl --user start laya-gpu    (GPU mode, port 8124)
#   systemctl --user enable --now laya-cpu   start at login
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p ~/.config/systemd/user
cp systemd/laya-cpu.service systemd/laya-gpu.service ~/.config/systemd/user/
systemctl --user daemon-reload
echo "Installed. Start with:  systemctl --user start laya-cpu   (or laya-gpu)"
