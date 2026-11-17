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
```

Then start Noctalia through it. Wherever your Hyprland config starts `noctalia` at
login (its exec-once entry), make it run this command instead:

```sh
sh -c '~/.local/bin/noctalia-build-assets && NOCTALIA_ASSETS_DIR=$HOME/.local/share/noctalia-nasapunk/assets exec noctalia'
```

Find that entry with `grep -rn noctalia ~/.config/hypr/`.

If Noctalia runs as a systemd user service instead, add a drop-in
(`systemctl --user edit noctalia`):

```ini
[Service]
Environment=NOCTALIA_ASSETS_DIR=%h/.local/share/noctalia-nasapunk/assets
ExecStartPre=%h/.local/bin/noctalia-build-assets
```

Undo: remove the variable (or the drop-in) and restart Noctalia.
