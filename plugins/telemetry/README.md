# Frosted telemetry (kunu/telemetry)

Two panels for Noctalia in the frosted telemetry style, both attached under the bar:
**quick settings** (`kunu/telemetry:quick`, bar widget `SYS`) and a curated
**settings** panel (`kunu/telemetry:settings`, bar widget `CFG`).

## Quick settings
Quick settings spec: Arch Rice project, `claude/spec-quick-settings.md` (A/B round 9).
Settings panel spec: `claude/spec-frosted-settings.md` (A/B round 10).

```
SYS // CONTROL                         FT-01
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

## Settings panel

Tabs `LOOK · BAR · MSGS · NIGHT · PLUGINS`, cycle choices `‹ M3 CONTENT ›`,
segmented numbers, bracket toggles, section serial tags (`L-01`…) and a footer.

| Tab | Settings (config path) |
|---|---|
| LOOK | `theme.mode`, `theme.wallpaper_scheme`, `shell.panel.transparency_mode`, `shell.settings_window_translucent`, `shell.animation.enabled/speed`, WALLPAPER › opens Noctalia's picker |
| BAR | `bar.main.thickness` (24–56 px), `bar.main.background_opacity`, `bar.main.auto_hide`, widget lanes for `bar.main.start/center/end` |
| MSGS | `notification.position/background_opacity/show_app_name/show_actions/group_by_app`, QUIET NOW (DND) |
| NIGHT | `nightlight.enabled` (schedule), `temperature_day`, `temperature_night` |
| PLUGINS | every plugin from `noctalia msg plugins list`, `[■]` enables/disables (this plugin is marked SELF and can't switch itself off) |

Values are read with `noctalia.getSetting()` and written with
`noctalia msg config-set <path> <toml>`. Noctalia keeps those writes in its own
`settings.toml` (they win over `config.toml`), clamps numbers to its ranges, and the
panel redraws when a value changes. `ALL SETTINGS ›` opens Noctalia's full window.
Footer: tab dots, `SYNC hh:mm` = last write to `settings.toml`, `T+` day of year.

**Bar lanes**: drag a chip within or between START / CENTER / END; click a chip for
`[‹] [›] [✕]`; `+` opens a picker of the widget names Noctalia accepts (built-ins plus
your `[widget.*]` instances).

## Install on the PC

Needs plugin API 46 (check `noctalia --version`; v5.4.1 or newer). Tools:
`pacman -Q networkmanager bluez-utils wireplumber` (brightnessctl optional).

1. Point Noctalia at this repo's `plugins/` folder as a path source and enable
   the plugin, in `~/.config/noctalia/config.toml`:

   ```toml
   [plugins]
   enabled = ["kunu/telemetry"]

   [[plugins.source]]
   name     = "kunu-dev"
   kind     = "path"
   location = "~/test-noc/plugins"   # wherever you cloned the repo
   enabled  = true
   ```

2. Add the two bar widgets:

   ```toml
   [widget.sys]
   type = "kunu/telemetry:sys"

   [widget.cfg]
   type = "kunu/telemetry:cfg"
   ```
   and in `[bar.main] end = [...]` replace `"control-center"` with `"sys", "cfg"`.

3. Optional keybind (Hyprland Lua), replacing Noctalia's control-center bind:

   ```lua
   hl.bind("SUPER+S", hl.dsp.exec_cmd("noctalia msg panel-toggle kunu/telemetry:quick"))
   hl.bind("SUPER+comma", hl.dsp.exec_cmd("noctalia msg panel-toggle kunu/telemetry:settings"))
   ```

Edits to `.luau` files hot-reload. Logs: `~/.cache/noctalia/noctalia.log`.

## IPC

```sh
noctalia msg panel-toggle kunu/telemetry:quick
noctalia msg plugin kunu/telemetry:quick all expand-net    # also collapse-net, refresh
noctalia msg panel-toggle kunu/telemetry:settings bar     # open on a tab
noctalia msg plugin kunu/telemetry:settings all tab night # also select <lane> <i>, add <lane>, drop end:1 center:end
```

## Harness

`harness/steps/frosted-settings.txt` (every tab + one real lane write) and
`harness/steps/telemetry.txt` with `PATH_PREPEND=/term/fixtures/full` (stub
nmcli/bluetoothctl/wpctl) or `/term/fixtures/min` (no tools). Fixtures exist
only in the harness.
