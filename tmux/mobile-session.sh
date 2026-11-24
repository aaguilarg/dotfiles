#!/usr/bin/env bash
#
# Creates (or attaches to) a tmux session for a RN/mobile project.
#
# Usage: mobile-session.sh -n|--name <session-name> [-p|--path <project-dir>]
#
# Attaches if the session already exists; creating it requires the path.
#
# Layout:
#   Window 1 "metro" — 2 panes (left: pnpm dev typed but not run; right: blank)
#   Window 2 "editor"   — nvim .
#   Window 3 "claude" — claude code, started at the git root of <project-dir>
#                       (the monorepo root for mobile/*, where .claude/ lives)
#

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") -n|--name <session-name> [-p|--path <project-dir>]" >&2
  exit 1
}

SESSION=""
PROJECT_DIR=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -n|--name) SESSION="${2:-}"; shift 2 || usage ;;
    -p|--path) PROJECT_DIR="${2:-}"; shift 2 || usage ;;
    *) usage ;;
  esac
done

if [ -z "$SESSION" ]; then
  usage
fi

attach_or_switch() {
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$SESSION"
  else
    tmux attach-session -t "$SESSION"
  fi
}

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

CLAUDE_DIR=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$PROJECT_DIR")

# --- Window 1: metro (2 side-by-side panes) ---
tmux new-session -d -s "$SESSION" -n "metro" -c "$PROJECT_DIR"
tmux split-window -h -t "$SESSION:1.0" -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION:1.0" 'pnpm dev'

# --- Window 2: editor ---
tmux new-window -t "$SESSION" -n "editor" -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION:2" 'nvim .' C-m

# --- Window 3: claude code ---
tmux new-window -t "$SESSION" -n "claude" -c "$CLAUDE_DIR"
tmux send-keys -t "$SESSION:3" 'claude' C-m

tmux select-window -t "$SESSION:1"

attach_or_switch
