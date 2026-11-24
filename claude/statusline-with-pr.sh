#!/bin/bash
# Claude Code status bar: the upstream ~/.claude/statusline.sh, unmodified so an update is a plain replace,
# plus the current branch's open PR from `pr-review-digest --bar`, right after dir@branch.
# A GitHub check takes 1.5-3.5 s and the bar redraws on every message, so the PR text is cached per
# checkout and branch, and refreshed in the background at most once a minute.

input=$(cat)
bar=$(printf '%s' "$input" | "$HOME/.claude/statusline.sh")

esc=$'\033'
reset="${esc}[0m"
dim="${esc}[2m"
green="${esc}[38;2;0;160;0m"
orange="${esc}[38;2;255;176;85m"
yellow="${esc}[38;2;230;200;0m"
cache_ttl=60

cached_pr_text() {
  local top="$1" branch="$2" dir cache mtime
  dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline-pr"
  cache="$dir/$(md5 -qs "$top|$branch")"
  mtime=$(stat -f %m "$cache" 2>/dev/null || echo 0)
  if [ $(( $(date +%s) - mtime )) -ge "$cache_ttl" ]; then
    mkdir -p "$dir" && touch "$cache"
    (
      cd "$top" || exit
      "$HOME/.local/bin/pr-review-digest" --bar > "$cache.$$" 2>/dev/null
      mv -f "$cache.$$" "$cache"
    ) </dev/null >/dev/null 2>&1 &
  fi
  cat "$cache" 2>/dev/null
}

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
top=$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null)
branch=$(git -C "${cwd:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null)
text=""
[ -n "$top" ] && [ -n "$branch" ] && [ "$branch" != "HEAD" ] && text=$(cached_pr_text "$top" "$branch")

if [ -z "$text" ]; then
  printf '%s' "$bar"
  exit 0
fi

case "$text" in
  *draft*) color="$dim" ;;
  *reviewing*) color="$yellow" ;;
  *"new review"*) color="$orange" ;;
  *) color="$green" ;;
esac
segment=" ${color}${text}${reset}"

line1=${bar%%$'\n'*}
rest=${bar#"$line1"}
marker="${green}${branch}${reset}"
sep=" ${dim}|${reset} "
if [[ "$line1" == *"$marker"* ]]; then
  before="${line1%%"$marker"*}$marker"
  after=${line1#*"$marker"}
  if [[ "$after" == *"$sep"* ]]; then
    line1="$before${after%%"$sep"*}$segment$sep${after#*"$sep"}"
  else
    line1="$before$after$segment"
  fi
else
  line1="$line1$segment"
fi
printf '%s%s' "$line1" "$rest"
