# NASA-SYS (kunu/nasa-sys)

Bracket-toggle control panel for Noctalia, attached under the bar.
Spec: Arch Rice project, `claude/spec-nasa-sys-panel.md` (A/B round 9).

```
SYS // CONTROL                         NP-01
────────────────────────────────────────────
[■] NET                       HOME-5G  ›
[■] BT LINK                     2 DEV
[ ] QUIET
[-] NIGHT
VOL ▮▮▮▮▮▮▮▮▮▮▯▯▯▯▯▯                    62
BRT ▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯             NO SIGNAL
CPU 3%          GPU 41°           RAM 9%
⏻ PWR                         SESSION  ›
▪▪▫▫ ·· ··        UPT 04:12:33     T+321
```

## What each row uses

| Row | Reads | Changes |
|---|---|---|
| NET | `nmcli radio wifi`, `nmcli -t -f IN-USE,SSID,SIGNAL dev wifi list` | `nmcli radio wifi on/off`; click a network: `nmcli dev wifi connect <SSID>` (falls back to Noctalia's network tab) |
| BT LINK | `bluetoothctl show`, `bluetoothctl devices Connected` | `bluetoothctl power on/off` |
| QUIET | `noctalia msg notification-dnd-status` | `notification-dnd-toggle` |
| NIGHT | nothing: Noctalia exposes no night-light state, so it shows `[-]` | `nightlight-force-toggle` |
| VOL | `wpctl get-volume @DEFAULT_AUDIO_SINK@` | click a segment: `wpctl set-volume`; click "VOL": mute toggle |
| BRT | `brightnessctl -m` | `brightnessctl set N%` (no backlight → `NO SIGNAL`) |
| CPU/GPU/RAM | `noctalia.systemStats()` (GPU sampling only while open) | — |
| PWR | — | opens Noctalia's session panel |

Missing tool → `NO SIGNAL`; unknown value → `--` / `[-]`. Nothing is made up.
It polls only while open: state every 5 s, uptime and stats every second.

## Install on the PC

Needs plugin API 46 (check `noctalia --version`; v5.4.1 or newer). Tools:
`pacman -Q networkmanager bluez-utils wireplumber` (brightnessctl optional).

1. Point Noctalia at this repo's `plugins/` folder as a path source and enable
   the plugin, in `~/.config/noctalia/config.toml`:

   ```toml
   [plugins]
   enabled = ["kunu/nasa-sys"]

   [[plugins.source]]
   name     = "kunu-dev"
   kind     = "path"
   location = "~/test-noc/plugins"   # wherever you cloned the repo
   enabled  = true
   ```

2. Swap the bar's control-center button for the SYS widget:

   ```toml
   [widget.sys]
   type = "kunu/nasa-sys:sys"
   ```
   and in `[bar.main] end = [...]` replace `"control-center"` with `"sys"`.

3. Optional keybind (Hyprland Lua), replacing Noctalia's control-center bind:

   ```lua
   hl.bind("SUPER+S", hl.dsp.exec_cmd("noctalia msg panel-toggle kunu/nasa-sys:panel"))
   ```

Edits to `.luau` files hot-reload. Logs: `~/.cache/noctalia/noctalia.log`.

## IPC

```sh
noctalia msg panel-toggle kunu/nasa-sys:panel
noctalia msg plugin kunu/nasa-sys:panel all expand-net    # also collapse-net, refresh
```

## Harness

`harness/steps/nasa-sys.txt` with `PATH_PREPEND=/term/fixtures/full` (stub
nmcli/bluetoothctl/wpctl) or `/term/fixtures/min` (no tools). Fixtures exist
only in the harness.
