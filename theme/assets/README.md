# Asset override (UPPERCASE labels)

Noctalia reads every shell label from `translations/en.json` in its asset folder.
If `NOCTALIA_ASSETS_DIR` points at a folder that contains `translations/en.json`,
Noctalia uses that folder instead of the installed one. `build_assets.py` makes
such a folder: a full copy of the installed assets with UPPERCASE labels and the
NASA wording (NET, BT LINK, QUIET, NIGHT, PWR...). The Settings window keeps
normal sentence case.

Rebuild it before every start: after a Noctalia update the copy would be missing
new strings and show raw keys like `control-center.foo`.

## Install on the PC

```fish
mkdir -p ~/.local/bin
cp build_assets.py ~/.local/bin/noctalia-build-assets
chmod +x ~/.local/bin/noctalia-build-assets
~/.local/bin/noctalia-build-assets   # test: prints "<src> -> <dst>"
```

## Start Noctalia from Hyprland (recommended)

Noctalia's docs recommend compositor autostart as the primary method
(docs/user/getting-started/running-the-shell). In `~/.config/hypr/hyprland.lua`,
inside your existing `hyprland.start` hook, replace the plain `noctalia` start with:

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd("sh -c '~/.local/bin/noctalia-build-assets; NOCTALIA_ASSETS_DIR=$HOME/.local/share/noctalia-nasapunk/assets exec noctalia'")
end)
```

The `;` (not `&&`) means Noctalia still starts if the build fails. With no
override folder it uses the installed assets; with an old one left over from
before an update, some labels may show raw keys until the script runs cleanly.

Start it once only. Check with `grep -rn noctalia ~/.config/hypr/` and
`systemctl --user is-enabled noctalia.service` (should be "disabled" or "not-found").
Two instances fight over layout space.

## systemd service (only if Hyprland runs under uwsm)

Noctalia's `noctalia.service` (Type=notify) supports Hyprland only in uwsm
sessions (docs/user/compositor-settings/systemd-service). If you ever switch to
uwsm, copy `/usr/share/noctalia/assets/noctalia.service` to
`~/.config/systemd/user/`, uncomment `WantedBy=wayland-session@hyprland.desktop.target`,
remove the Hyprland autostart line, then add a drop-in (`systemctl --user edit noctalia`):

```ini
[Service]
Environment=NOCTALIA_ASSETS_DIR=%h/.local/share/noctalia-nasapunk/assets
ExecStartPre=-%h/.local/bin/noctalia-build-assets
```

## Undo

Start plain `noctalia` again (or drop the `Environment=` line) and restart Noctalia.
