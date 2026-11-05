#!/usr/bin/env bash
# Runs INSIDE the harness container. Starts headless sway, launches Noctalia,
# runs optional IPC steps, and writes screenshots to /out.
#   env: RES=3840x2160  SETTLE=3  READY_TIMEOUT=60  NOCTALIA=/bundle/noctalia
#   /xdg/config/noctalia -> your config dir (contains config.toml)
#   /steps -> optional steps file (see README)
set -uo pipefail

RES="${RES:-3840x2160}"
SETTLE="${SETTLE:-3}"          # seconds to draw after IPC is up
READY_TIMEOUT="${READY_TIMEOUT:-60}"
NOCTALIA="${NOCTALIA:-/bundle/noctalia}"
OUT=/out
mkdir -p "$OUT"

export XDG_RUNTIME_DIR=/tmp/xdg
mkdir -p -m 700 "$XDG_RUNTIME_DIR"
export WLR_BACKENDS=headless
export WLR_RENDERER=pixman
export WLR_LIBINPUT_NO_DEVICES=1
export LIBGL_ALWAYS_SOFTWARE=1
# Noctalia appends "/noctalia" to these, so /cfg is mounted at /xdg/config/noctalia.
export NOCTALIA_CONFIG_HOME=/xdg/config
export NOCTALIA_STATE_HOME=/tmp/state
mkdir -p "$NOCTALIA_STATE_HOME/noctalia"
# Skip the first-run wizard (it only checks for this marker in the state dir).
touch "$NOCTALIA_STATE_HOME/noctalia/.setup-complete"

# Pick up theme fonts mounted by shot.sh.
[ -d /usr/local/share/fonts/theme ] && fc-cache -f /usr/local/share/fonts > /dev/null 2>&1

# A session bus, so D-Bus services Noctalia expects can at least connect.
eval "$(dbus-launch --sh-syntax)"

cat > /tmp/sway.conf <<EOF
output HEADLESS-1 resolution $RES position 0 0 scale 1 bg #3a3d40 solid_color
default_border none
EOF

sway -c /tmp/sway.conf > "$OUT/sway.log" 2>&1 &
for _ in $(seq 50); do
  WAYLAND_DISPLAY=$(ls "$XDG_RUNTIME_DIR" 2>/dev/null | grep -m1 -E '^wayland-[0-9]+$')
  [ -n "${WAYLAND_DISPLAY:-}" ] && break
  sleep 0.2
done
[ -z "${WAYLAND_DISPLAY:-}" ] && { echo "sway did not start"; cat "$OUT/sway.log"; exit 1; }
export WAYLAND_DISPLAY
export SWAYSOCK=$(ls "$XDG_RUNTIME_DIR"/sway-ipc.*.sock 2>/dev/null | head -1)

status=0
if [ -f /xdg/config/noctalia/config.toml ]; then
  "$NOCTALIA" config validate > "$OUT/validate.log" 2>&1 || { echo "config validate FAILED"; status=2; }
fi

"$NOCTALIA" > "$OUT/noctalia.log" 2>&1 &
NPID=$!

# Wait until Noctalia answers IPC (not a fixed sleep: startup time varies a lot
# with cold caches and software rendering), then give it SETTLE s to draw.
ready=0
for _ in $(seq "$((READY_TIMEOUT * 2))"); do
  if ! kill -0 "$NPID" 2>/dev/null; then
    echo "noctalia exited early (crash or config error), see noctalia.log"
    tail -30 "$OUT/noctalia.log"
    exit 3
  fi
  if "$NOCTALIA" msg status > "$OUT/status.json" 2>/dev/null; then ready=1; break; fi
  sleep 0.5
done
if [ "$ready" != 1 ]; then
  echo "noctalia did not answer IPC within ${READY_TIMEOUT}s, see noctalia.log"
  exit 4
fi
sleep "$SETTLE"

grim "$OUT/00-desktop.png"

# Steps file, one step per line:
#   <name> <wait-seconds> <noctalia args...> [ | <cleanup noctalia args...> ]
# Default cleanup is `msg panel-close`. Name `_` = run the command, no screenshot
# (setup steps). Lines with `-` as cleanup skip cleanup. Commands run with `sh -c`
# semantics for quoting, e.g.  toast 2 msg notification-show "Hello there"
run() {  # run noctalia with a quoted arg string
  eval "set -- $1"
  "$NOCTALIA" "$@" >> "$OUT/ipc.log" 2>&1
}
if [ -f /steps ]; then
  n=1
  while IFS= read -r line; do
    [[ -z "${line// }" || "$line" =~ ^[[:space:]]*# ]] && continue
    read -r name wait rest <<< "$line"
    cmd="${rest%%|*}"; cleanup="msg panel-close"
    [[ "$rest" == *"|"* ]] && cleanup="${rest#*|}"
    echo ">> $name: $cmd" >> "$OUT/ipc.log"
    run "$cmd" || echo "step $name: ipc failed" >> "$OUT/ipc.log"
    sleep "$wait"
    if [ "$name" != "_" ]; then
      grim "$OUT/$(printf '%02d' $n)-$name.png"
      n=$((n + 1))
    fi
    cleanup="$(echo "$cleanup" | xargs)"
    [ "$cleanup" != "-" ] && { run "$cleanup" || true; }
    sleep 0.7
  done < /steps
fi

grep -iE "error|fatal|crit" "$OUT/noctalia.log" > "$OUT/errors.log" || true
kill "$NPID" 2>/dev/null
# A frame with nothing but sway's flat background compresses to a few KB.
blank=0
for f in "$OUT"/*.png; do
  if [ "$(stat -c %s "$f")" -lt 30000 ]; then
    echo "WARN: $(basename "$f") looks blank (Noctalia not drawn yet?)"; blank=$((blank + 1))
  fi
done
[ "$blank" -gt 0 ] && [ "$status" = 0 ] && status=5
echo "DONE: $(ls "$OUT"/*.png | wc -l) screenshot(s), $blank blank, $(wc -l < "$OUT/errors.log") error line(s) in log"
exit $status
