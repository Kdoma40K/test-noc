#!/usr/bin/env bash
# Opens foot running the fish demo with the theme's foot.ini.
# Ubuntu's foot (1.25) predates the [colors-dark] section that Noctalia's template and
# the theme's foot.ini use (Arch ships a newer foot), so the harness copies rename it to [colors].
export LANG=C.UTF-8
mkdir -p ~/.config/foot/themes
cp /xdg/config/noctalia/foot/foot.ini ~/.config/foot/foot.ini
cp ~/.config/foot/themes/noctalia ~/.config/foot/themes/noctalia-compat
sed -i 's/^\[colors-dark\]/[colors]/; /^\[colors-light\]/,$d' ~/.config/foot/themes/noctalia-compat
sed -i 's|themes/noctalia$|themes/noctalia-compat|; s/^\[colors-dark\]/[colors]/' ~/.config/foot/foot.ini
exec foot fish /term/demo.fish
