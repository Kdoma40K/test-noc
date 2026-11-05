#!/usr/bin/env bash
# Runs INSIDE the harness container. Starts headless sway, launches Noctalia,
# runs optional IPC steps, and writes screenshots to /out.
#   env: RES=3840x2160  SETTLE=6  NOCTALIA=/bundle/noctalia
#   /xdg/config/noctalia -> your config dir (contains config.toml)
#   /steps -> optional steps file (see README)
set -uo pipefail

RES="${RES:-3840x2160}"
SETTLE="${SETTLE:-6}"
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
sleep "$SETTLE"

if ! kill -0 "$NPID" 2>/dev/null; then
  echo "noctalia exited early (crash or config error), see noctalia.log"
  tail -30 "$OUT/noctalia.log"
  exit 3
fi

grim "$OUT/00-desktop.png"

# Steps file: one line per step:  <name> <wait-seconds> <noctalia args...>
# e.g.   launcher 2 msg panel-open launcher
# After each screenshot the harness runs `msg panel-close`.
if [ -f /steps ]; then
  n=1
  while read -r name wait rest; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    # shellcheck disable=SC2086
    "$NOCTALIA" $rest >> "$OUT/ipc.log" 2>&1 || echo "step $name: ipc failed" >> "$OUT/ipc.log"
    sleep "$wait"
    grim "$OUT/$(printf '%02d' $n)-$name.png"
    "$NOCTALIA" msg panel-close >/dev/null 2>&1 || true
    sleep 0.5
    n=$((n + 1))
  done < /steps
fi

grep -iE "error|fatal|crit" "$OUT/noctalia.log" > "$OUT/errors.log" || true
kill "$NPID" 2>/dev/null
echo "OK: $(ls "$OUT"/*.png | wc -l) screenshot(s), $(wc -l < "$OUT/errors.log") error line(s) in log"
exit $status
