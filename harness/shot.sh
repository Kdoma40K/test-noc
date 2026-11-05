#!/usr/bin/env bash
# Screenshot Noctalia with a given config, in a headless container.
#   ./shot.sh [config-dir] [out-dir] [steps-file]
#   config-dir : folder with config.toml (default: Noctalia's stock example)
#   out-dir    : where PNGs and logs land (default: ./out/<timestamp>)
#   env RES=3840x2160 SETTLE=6 to override resolution / settle time
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="$HERE/../.bundle"
[ -x "$BUNDLE/noctalia" ] || { echo "no bundle, run ./setup.sh first"; exit 1; }

# Claude's workspace stops background processes between turns, dockerd included.
if ! sudo docker info >/dev/null 2>&1; then
  (sudo env HTTPS_PROXY="${HTTPS_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" \
     NO_PROXY=localhost,127.0.0.1 dockerd > /tmp/dockerd.log 2>&1 &)
  for _ in $(seq 30); do sudo docker info >/dev/null 2>&1 && break; sleep 1; done
fi
CFG="${1:-}"
OUT="${2:-$HERE/out/$(date +%Y%m%d-%H%M%S)}"
STEPS="${3:-}"

if [ -z "$CFG" ]; then
  CFG="$(mktemp -d)"
  cp "$BUNDLE/example.toml" "$CFG/config.toml"
fi
CFG="$(cd "$CFG" && pwd)"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"; chmod 777 "$OUT"; chmod -R a+rwX "$CFG"

args=(--rm --network host
      -e RES="${RES:-3840x2160}" -e SETTLE="${SETTLE:-6}"
      -v "$BUNDLE":/bundle:ro -v "$CFG":/xdg/config/noctalia -v "$OUT":/out
      -v "$HERE/inner.sh":/inner.sh:ro)
[ -n "$STEPS" ] && args+=(-v "$(cd "$(dirname "$STEPS")" && pwd)/$(basename "$STEPS")":/steps:ro)

sudo docker run "${args[@]}" noctalia-harness bash /inner.sh
echo "Output: $OUT"
