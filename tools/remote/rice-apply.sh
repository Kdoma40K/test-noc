#!/usr/bin/env bash
# Usage: rice-apply.sh apply | rollback | list
# Copies this repo's theme/config.toml to the live Noctalia config (hot-reloads),
# backing up the current one first. This is the ONLY file it writes.
set -euo pipefail
SRC="$(git rev-parse --show-toplevel)/theme/config.toml"
DEST="$HOME/.config/noctalia/config.toml"
BACKUPS="$HOME/.local/state/rice-backups"
mkdir -p "$BACKUPS" "$(dirname "$DEST")"

case "${1:-}" in
  apply)
    [ -f "$SRC" ] || { echo "missing $SRC"; exit 1; }
    stamp="$(date +%Y%m%d-%H%M%S)"
    [ -f "$DEST" ] && cp -a "$DEST" "$BACKUPS/config-$stamp.toml"
    cp "$SRC" "$DEST"
    echo "applied $(git rev-parse --short HEAD); backup: config-$stamp.toml"
    ;;
  rollback)
    last="$(ls -1 "$BACKUPS" 2>/dev/null | sort | tail -n1)"
    [ -n "$last" ] || { echo "no backups"; exit 1; }
    cp "$BACKUPS/$last" "$DEST"
    rm -f "$BACKUPS/$last"
    echo "rolled back to $last"
    ;;
  list) ls -1 "$BACKUPS" | sort ;;
  *) echo "usage: $0 apply|rollback|list"; exit 1 ;;
esac
