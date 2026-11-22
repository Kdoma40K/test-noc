#!/usr/bin/env bash
# Copy the live configs on this PC into dotfiles/, and refresh the package lists.
# Run after any change, then commit and push to the `active` branch:
#   ./dotfiles/sync.sh && git add -A dotfiles && git commit -m "..." && git push
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ZEN="$(ls -d "$HOME"/.config/zen/*.Default\ \(release\) | head -1)"

# repo path (under dotfiles/)              live path
FILES=(
  "home/.config/noctalia/config.toml        $HOME/.config/noctalia/config.toml"
  "home/.local/state/noctalia/settings.toml $HOME/.local/state/noctalia/settings.toml"
  "home/.config/hypr/hyprland.lua           $HOME/.config/hypr/hyprland.lua"
  "home/.config/hypr/custom/noctalia-blur.lua $HOME/.config/hypr/custom/noctalia-blur.lua"
  "home/.config/kitty/kitty.conf            $HOME/.config/kitty/kitty.conf"
  "home/.config/foot/foot.ini               $HOME/.config/foot/foot.ini"
  "home/.config/fish/config.fish            $HOME/.config/fish/config.fish"
  "home/.config/starship.toml               $HOME/.config/starship.toml"
  "home/.config/mimeapps.list               $HOME/.config/mimeapps.list"
  "home/.config/qt5ct/qt5ct.conf            $HOME/.config/qt5ct/qt5ct.conf"
  "home/.config/qt6ct/qt6ct.conf            $HOME/.config/qt6ct/qt6ct.conf"
  "home/.config/gh/config.yml               $HOME/.config/gh/config.yml"
  "home/.local/share/applications/yazi.desktop $HOME/.local/share/applications/yazi.desktop"
  "home/.config/zen/profile/user.js         $ZEN/user.js"
  "home/.config/zen/profile/chrome/userChrome.css  $ZEN/chrome/userChrome.css"
  "home/.config/zen/profile/chrome/userContent.css $ZEN/chrome/userContent.css"
  "etc/greetd/config.toml                   /etc/greetd/config.toml"
)

for entry in "${FILES[@]}"; do
  read -r dst src <<<"$entry"
  # paths with spaces (Zen profile): everything after the first field is the source
  src="${entry#"$dst"}"; src="${src#"${src%%[![:space:]]*}"}"
  if [ -f "$src" ]; then
    mkdir -p "$HERE/$(dirname "$dst")"
    cp "$src" "$HERE/$dst"
  else
    echo "missing: $src" >&2
  fi
done

mkdir -p "$HERE/packages"
pacman -Qqen > "$HERE/packages/pacman.txt"   # explicitly installed, official repos
pacman -Qqm  > "$HERE/packages/aur.txt"      # AUR / foreign
echo "synced into $HERE"
