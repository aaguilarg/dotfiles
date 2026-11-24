#!/usr/bin/env bash
# Claude Code statusLine command
# Inspired by the p10k rainbow prompt
#
# Layout:
#   left:  dir  branch [worktree]
#   right: [vim] ["session"]  Model  ctx:N%  $0.00  +N -N  ██░░ RL% ~HH:MM  HH:MM

input=$(cat)

# --- Extract all fields with a single jq call for speed ---
eval "$(echo "$input" | jq -r '
  @sh "cwd=\(.workspace.current_dir // .cwd // "")",
  @sh "model=\(.model.display_name // "")",
  @sh "used_pct=\(.context_window.used_percentage // "")",
  @sh "session_name=\(.session_name // "")",
  @sh "vim_mode=\(.vim.mode // "")",
  @sh "cost_usd=\(.cost.total_cost_usd // "")",
  @sh "lines_added=\(.cost.total_lines_added // "")",
  @sh "lines_removed=\(.cost.total_lines_removed // "")",
  @sh "rl_5h_pct=\(.rate_limits.five_hour.used_percentage // "")",
  @sh "rl_5h_resets=\(.rate_limits.five_hour.resets_at // "")",
  @sh "wt_name=\(.worktree.name // "")",
  @sh "cache_read=\(.context_window.current_usage.cache_read_input_tokens // "")",
  @sh "cache_create=\(.context_window.current_usage.cache_creation_input_tokens // "")",
  @sh "input_tokens=\(.context_window.current_usage.input_tokens // "")"
')"

# --- ANSI colors ---
reset='\033[0m'
bold='\033[1m'
dim='\033[2m'
cyan='\033[36m'
yellow='\033[33m'
green='\033[32m'
magenta='\033[35m'
blue='\033[34m'
red='\033[31m'
white='\033[37m'

# --- Directory (shorten $HOME to ~) ---
display_dir="${cwd/#$HOME/~}"

# --- Git branch (skip locks to stay fast) ---
git_branch=""
if git_out=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  git_branch="$git_out"
elif git_out=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null); then
  git_branch="$git_out"
fi

# === LEFT SIDE: dir + branch + worktree ===
left=""
printf -v left "%b%s%b" "$cyan" "$display_dir" "$reset"

if [ -n "$git_branch" ]; then
  printf -v part " %b%s%b" "$yellow" "$git_branch" "$reset"
  left="${left}${part}"
fi

if [ -n "$wt_name" ]; then
  printf -v part " %b[%s]%b" "$magenta" "$wt_name" "$reset"
  left="${left}${part}"
fi

# === RIGHT SIDE ===
right=""

# Vim mode
if [ -n "$vim_mode" ]; then
  if [ "$vim_mode" = "NORMAL" ]; then
    printf -v part "%b[N]%b " "$green" "$reset"
  else
    printf -v part "%b[I]%b " "$blue" "$reset"
  fi
  right="${right}${part}"
fi

# Session name
if [ -n "$session_name" ]; then
  printf -v part "%b\"%s\"%b  " "$magenta" "$session_name" "$reset"
  right="${right}${part}"
fi

# Model
if [ -n "$model" ]; then
  printf -v part "%b%s%b" "$white" "$model" "$reset"
  right="${right}${part}"
fi

# Context usage
if [ -n "$used_pct" ]; then
  used_int=$(printf '%.0f' "$used_pct")
  if   [ "$used_int" -ge 80 ]; then color="$red"
  elif [ "$used_int" -ge 50 ]; then color="$yellow"
  else                               color="$green"
  fi
  printf -v part "  %bctx:%s%%%b" "$color" "$used_int" "$reset"
  right="${right}${part}"
fi

# Cost
if [ -n "$cost_usd" ]; then
  # Format to 2 decimal places
  cost_fmt=$(printf '%.2f' "$cost_usd")
  cost_cents=$(printf '%.0f' "$(echo "$cost_usd * 100" | bc 2>/dev/null || echo "0")")
  if   [ "$cost_cents" -ge 500 ] 2>/dev/null; then color="$red"
  elif [ "$cost_cents" -ge 100 ] 2>/dev/null; then color="$yellow"
  else                                              color="$green"
  fi
  printf -v part "  %b\$%s%b" "$color" "$cost_fmt" "$reset"
  right="${right}${part}"
fi

# Lines changed (compact diff stat)
if [ -n "$lines_added" ] || [ -n "$lines_removed" ]; then
  diff_stat=""
  if [ -n "$lines_added" ] && [ "$lines_added" != "0" ]; then
    printf -v part "%b+%s%b" "$green" "$lines_added" "$reset"
    diff_stat="$part"
  fi
  if [ -n "$lines_removed" ] && [ "$lines_removed" != "0" ]; then
    printf -v part "%b-%s%b" "$red" "$lines_removed" "$reset"
    if [ -n "$diff_stat" ]; then
      diff_stat="${diff_stat} ${part}"
    else
      diff_stat="$part"
    fi
  fi
  if [ -n "$diff_stat" ]; then
    right="${right}  ${diff_stat}"
  fi
fi

# Rate limit (5h) with mini progress bar + reset time
if [ -n "$rl_5h_pct" ]; then
  rl_int=$(printf '%.0f' "$rl_5h_pct")
  if   [ "$rl_int" -ge 80 ]; then color="$red"
  elif [ "$rl_int" -ge 50 ]; then color="$yellow"
  else                              color="$green"
  fi

  # Mini progress bar (5 chars wide)
  filled=$((rl_int / 20))
  empty=$((5 - filled))
  bar=""
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty; i++));  do bar="${bar}░"; done

  printf -v part "  %b%s %s%%%b" "$color" "$bar" "$rl_int" "$reset"
  right="${right}${part}"

  # Reset countdown
  if [ -n "$rl_5h_resets" ]; then
    now=$(date +%s)
    diff_secs=$((rl_5h_resets - now))
    if [ "$diff_secs" -gt 0 ]; then
      diff_hrs=$((diff_secs / 3600))
      diff_mins=$(( (diff_secs % 3600) / 60 ))
      printf -v part " %b~%d:%02d%b" "$dim" "$diff_hrs" "$diff_mins" "$reset"
      right="${right}${part}"
    fi
  fi
fi

# Cache hit ratio
if [ -n "$cache_read" ] && [ -n "$input_tokens" ] && [ "$input_tokens" != "0" ]; then
  total_input=$((cache_read + cache_create + input_tokens))
  if [ "$total_input" -gt 0 ] 2>/dev/null; then
    hit_pct=$((cache_read * 100 / total_input))
    if [ "$hit_pct" -ge 50 ]; then color="$green"
    else                            color="$yellow"
    fi
    printf -v part "  %b$%s%%%b" "$color" "$hit_pct" "$reset"
    right="${right}${part}"
  fi
fi

# Time
printf -v part "  %b%s%b" "$dim" "$(date +%H:%M)" "$reset"
right="${right}${part}"

# --- Print ---
printf "%b  %s  |  %s\n" "$reset" "$left" "$right"
