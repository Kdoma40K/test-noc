#!/usr/bin/env bash
# Keeps a Claude Code Remote Control server alive. Run inside tmux.
REPO="${TEST_NOC_DIR:-$HOME/test-noc}"   # <- set to where you cloned test-noc
LOG="$HOME/.local/state/claude-rc.log"
mkdir -p "$(dirname "$LOG")"
cd "$REPO" || { echo "no repo at $REPO" >>"$LOG"; exit 1; }

while true; do
  echo "[$(date '+%F %T')] starting" >>"$LOG"
  claude remote-control \
    --spawn worktree \
    --permission-mode acceptEdits \
    --remote-control-session-name-prefix kunu-pc
  echo "[$(date '+%F %T')] exited code $? - restarting in 20s" >>"$LOG"
  sleep 20
done
