#!/usr/bin/env bash
# Sends one critical and one normal notification over D-Bus (urgency hint 2 = critical).
n() { gdbus call --session --dest org.freedesktop.Notifications \
  --object-path /org/freedesktop/Notifications \
  --method org.freedesktop.Notifications.Notify \
  "$1" 0 "$2" "$3" "$4" "[]" "{'urgency': <byte $5>}" 0; }
n "Power" "battery-caution" "Battery critical" "5% remaining. Plug in now." 2
sleep 0.4
n "Update radar" "system-software-update" "Updates available" "14 packages pending" 1
