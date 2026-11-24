#!/usr/bin/env bash
#
# Creates (or attaches to) a tmux session for a Rails project.
#
# Usage: rails-session.sh -n|--name <session-name> [-p|--path <project-dir>] [-j|--jobs] [-e|--extra <command>]
#
# Attaches if the session already exists; creating it requires the path.
#
# Layout:
#   Window 1 "rails server" — default (3 top panes):
#     ┌──────────┬──────────┬──────────┐
#     │  dcup    │   rs     │   bwp    │  (3 equal-width panes)
#     ├──────────┴──────────┴──────────┤
#     │             rc                 │  (full-width bottom pane)
#     └────────────────────────────────┘
#   With -j|--jobs (4 top panes, bin/jobs between rs and bwp):
#     ┌────────┬────────┬────────┬────────┐
#     │  dcup  │   rs   │   bj   │  bwp   │
#     ├────────┴────────┴────────┴────────┤
#     │                rc                 │
#     └───────────────────────────────────┘
#   With -e|--extra <command>, the bottom row splits in two: rc on the left,
#   <command> on the right (run from the Rails dir), e.g. a Telegram poller.
#   It is the last pane of window 1 (index 4 by default, 5 with -j).
#   Window 2 "editor"  — nvim
#   Window 3 "claude"  — claude, started at the git root of <project-dir>
#   Window 4 "console" — blank shell
#
# Monorepo detection: if <project-dir>/backend exists, panes cd where their
# command lives (dcup → root, rs/bj/rc → backend/, bwp → frontend/).
# Classic Rails-root repos run every pane in <project-dir>. For a workspace
# inside a bigger repo (e.g. <repo>/rails) only claude moves up to the
# repo root, where the repo's .claude/ config lives.
#

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") -n|--name <session-name> [-p|--path <project-dir>] [-j|--jobs] [-e|--extra <command>]" >&2
  exit 1
}

SESSION=""
PROJECT_DIR=""
WITH_JOBS=0
EXTRA_COMMAND=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -n|--name) SESSION="${2:-}"; shift 2 || usage ;;
    -p|--path) PROJECT_DIR="${2:-}"; shift 2 || usage ;;
    -j|--jobs) WITH_JOBS=1; shift ;;
    -e|--extra) EXTRA_COMMAND="${2:-}"; shift 2 || usage ;;
    *) usage ;;
  esac
done

if [ -z "$SESSION" ]; then
  usage
fi

# attach or switch to an existing/new session
attach_or_switch() {
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$SESSION"
  else
    tmux attach-session -t "$SESSION"
  fi
}

# If the session already exists, just attach/switch and exit
if tmux has-session -t "$SESSION" 2>/dev/null; then
  attach_or_switch
  exit 0
fi

if [ -z "$PROJECT_DIR" ]; then
  echo "Session '$SESSION' does not exist; pass -p|--path to create it" >&2
  exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Project dir does not exist: $PROJECT_DIR" >&2
  exit 1
fi

# Monorepo layout (backend/ + frontend/) vs classic Rails root
RAILS_DIR="$PROJECT_DIR"
FRONT_DIR="$PROJECT_DIR"
if [ -d "$PROJECT_DIR/backend" ]; then
  RAILS_DIR="$PROJECT_DIR/backend"
  [ -d "$PROJECT_DIR/frontend" ] && FRONT_DIR="$PROJECT_DIR/frontend"
fi
CLAUDE_DIR=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$PROJECT_DIR")

# --- Window 1: rails server ---
tmux new-session -d -s "$SESSION" -n "rails server" -c "$PROJECT_DIR"

# Split top/bottom (50/50); bottom pane is the console
tmux split-window -v -t "$SESSION:1.0" -c "$RAILS_DIR" -l 50%
# pane 0 = top, pane 1 = bottom

if [ "$WITH_JOBS" -eq 1 ]; then
  # Split top pane into 4 equal columns: 25% each
  tmux split-window -h -t "$SESSION:1.0" -c "$RAILS_DIR" -l 75%
  tmux split-window -h -t "$SESSION:1.1" -c "$RAILS_DIR" -l 67%
  tmux split-window -h -t "$SESSION:1.2" -c "$FRONT_DIR" -l 50%
  # panes: 0 dcup | 1 rs | 2 bj | 3 bwp | 4 rc (bottom)

  tmux send-keys -t "$SESSION:1.0" 'dcup' C-m
  tmux send-keys -t "$SESSION:1.1" 'rs' C-m
  tmux send-keys -t "$SESSION:1.2" 'bj' C-m
  tmux send-keys -t "$SESSION:1.3" 'bwp' C-m
  tmux send-keys -t "$SESSION:1.4" 'rc' C-m
else
  # Split top pane into 3 equal columns: 33% | 33% | 33%
  tmux split-window -h -t "$SESSION:1.0" -c "$RAILS_DIR" -l 67%
  tmux split-window -h -t "$SESSION:1.1" -c "$FRONT_DIR" -l 50%
  # panes: 0 dcup | 1 rs | 2 bwp | 3 rc (bottom)

  tmux send-keys -t "$SESSION:1.0" 'dcup' C-m
  tmux send-keys -t "$SESSION:1.1" 'rs' C-m
  tmux send-keys -t "$SESSION:1.2" 'bwp' C-m
  tmux send-keys -t "$SESSION:1.3" 'rc' C-m
fi

if [ -n "$EXTRA_COMMAND" ]; then
  RC_PANE=$((WITH_JOBS == 1 ? 4 : 3))
  tmux split-window -h -t "$SESSION:1.$RC_PANE" -c "$RAILS_DIR" -l 50%
  tmux send-keys -t "$SESSION:1.$((RC_PANE + 1))" "$EXTRA_COMMAND" C-m
fi

# --- Window 2: editor ---
tmux new-window -t "$SESSION" -n "editor" -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION:2" 'nvim .' C-m

# --- Window 3: claude ---
tmux new-window -t "$SESSION" -n "claude" -c "$CLAUDE_DIR"
tmux send-keys -t "$SESSION:3" 'claude' C-m

# --- Window 4: console (blank shell) ---
tmux new-window -t "$SESSION" -n "console" -c "$PROJECT_DIR"

# Select window 1 as the starting window
tmux select-window -t "$SESSION:1"

# Attach or switch to the session
attach_or_switch
