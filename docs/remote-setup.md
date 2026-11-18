# Remote ricing setup (phone → PC)

Goal: iterate on the Noctalia theme from the Claude app on the phone, test in
the Docker/sway harness, and apply to the live PC, while away for days.

```
phone (Claude app)
     │
     ▼
claude remote-control  (on PC, tmux, systemd user unit)
     ├─ harness/shot.sh ──▶ screenshots/ ──▶ git push
     └─ rice-apply.sh ──▶ ~/.config/noctalia/config.toml (backup first)
```

## Why it's built this way
- **Remote Control runs on the PC**, not in the cloud, so Docker and live
  config are reachable. Server mode (`claude remote-control`) exits after
  ~10 min offline, so `claude-rc.sh` loops it and the systemd unit starts it
  at boot (needs linger).
- **tmux** gives server mode the terminal it needs; systemd alone has none.
- **Tailscale SSH** is the fallback way in if Claude goes offline.
- **No sudo for Claude**: package scripts run as root, so passwordless pacman
  = root for Claude. Kunu runs root commands himself over SSH.
- **pc-shot** finds the Wayland socket itself, because the service runs
  outside the Hyprland session and lacks `WAYLAND_DISPLAY`.

## Install (fish)
```fish
set -Ux TEST_NOC_DIR ~/test-noc   # wherever this repo lives; also set in the unit if not ~/test-noc
tools/remote/install.sh
sudo loginctl enable-linger $USER
systemctl --user enable --now claude-rc
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
sudo pacman -S --needed tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up --ssh            # then disable key expiry for this PC in the admin console
```
Note: the systemd unit doesn't see fish universal vars. If the repo isn't at
`~/test-noc`, add `Environment=TEST_NOC_DIR=/path` to the unit.

## Verify
1. `systemctl --user status claude-rc` and `tmux ls` → running.
2. Phone, on mobile data: open the `kunu-pc-…` session, run one harness step.
3. `tmux kill-session -t claude-rc` → back within ~30 s.
4. `sudo reboot` → session reappears after boot.
5. Lock screen, then `pc-shot` over SSH → see what a locked capture looks like.

## Recovery from the phone (Tailscale SSH)
- Watch: `tmux attach -t claude-rc` (detach: Ctrl+b, d; not Ctrl+c)
- Log: `tail ~/.local/state/claude-rc.log`
- Restart: `systemctl --user restart claude-rc`
- Undo theme: `rice-apply.sh rollback`

## After the trip
`sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target`
