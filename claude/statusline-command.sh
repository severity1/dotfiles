#!/bin/bash
# Claude Code statusline - Optimized version (<100ms target)
# Line 1: [user][host][branch info][path]
# Line 2: [SESSION id][model ctx%][msg|tools][$cost][duration][+lines/-lines]
# Line 3: [TOTAL: tok|msg|sess|$cost|cached%][SINCE: date|avg]
# Line 4: [RECORDS: longest:dur/msg | peak:hour | mix:O:x%S:y%]
#
# Model rates ($/M tokens) - defined in jq queries for DRY
# Source: https://platform.claude.com/docs/en/about-claude/pricing
# Opus 4.5: $5/$25, Sonnet 4.5: $3/$15, Haiku 4.5: $1/$5
# Cache: read=0.1x input, write=1.25x input

# ==================== COLORS (Mairan Theme) ====================
# Bold colors matching ~/.oh-my-bash/themes/mairan/mairan.theme.sh
O="\033[1;33m"  # Orange - brackets, host
G="\033[1;32m"  # Green - user, branch, clean status, path
Y="\033[0;33m"  # Yellow/Brown - dirty status, warnings
R="\033[0;31m"  # Red - errors, critical
P="\033[1;35m"  # Purple - model name
D="\033[0;90m"  # Dim - secondary info
C="\033[0;36m"  # Cyan - system overhead
W="\033[0;37m"  # Gray/White - initial startup context
Z="\033[0m"     # Reset

# ==================== CONSTANTS ====================
BAR_LEN=12                    # Total bar character width
BAR_RESERVED=3                # Reserved chars for autocompact zone (~25%)
BAR_USABLE=9                  # Chars for actual usage (BAR_LEN - BAR_RESERVED)
CTX_WINDOW=200000             # Context window size
CTX_RESERVED=50000            # Autocompact zone (~25%)
CTX_USABLE=150000             # Usable context (CTX_WINDOW - CTX_RESERVED)
WARN_PCT=67                   # Warning threshold

# Shade density for granular bar animation (1/4 to 4/4)
SHADE_BLOCKS=("" "░" "▒" "▓")

# ==================== PLATFORM COMPATIBILITY ====================
# date commands differ between GNU (Linux) and BSD (macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
  date_to_epoch() { date -j -f "%Y-%m-%dT%H:%M:%S" "${1%%.*}" +%s 2>/dev/null || echo 0; }
  date_fmt() { date -j -f "%Y-%m-%d" "$1" "+%b %d, %Y" 2>/dev/null || echo "$1"; }
else
  date_to_epoch() { date -d "$1" +%s 2>/dev/null || echo 0; }
  date_fmt() { date -d "$1" "+%b %d, %Y" 2>/dev/null || echo "$1"; }
fi

# ==================== HELPER FUNCTIONS ====================
fmt_tok() {
  local t=$1
  [[ -z "$t" || "$t" == "null" || "$t" == "0" ]] && echo "0" && return
  ((t >= 1000000000)) && printf "%.1fB" "$(bc -l <<< "$t/1000000000")" && return
  ((t >= 1000000)) && printf "%.1fM" "$(bc -l <<< "$t/1000000")" && return
  ((t >= 1000)) && printf "%.0fk" "$(bc -l <<< "$t/1000")" && return
  echo "$t"
}

fmt_dur() {
  local s=$1
  [[ -z "$s" || "$s" == "0" ]] && echo "0m" && return
  local m=$((s/60)) h=$((s/3600)) d=$((s/86400))
  ((d > 0)) && echo "${d}d $((h%24))h" && return
  ((h > 0)) && echo "${h}h $((m%60))m" && return
  echo "${m}m"
}

# Extract initial tokens (all cached system content - prompts, tools, CLAUDE.md)
get_initial_tokens() {
  local json="$1"
  echo "$json" | jq -r '
    (.cache_read_input_tokens // 0) +
    (.cache_creation_input_tokens // 0)
  ' 2>/dev/null || echo 0
}

# Extract "ours" tokens (actual conversation content)
get_ours_tokens() {
  local json="$1"
  echo "$json" | jq -r '
    (.input_tokens // 0) +
    (.output_tokens // 0)
  ' 2>/dev/null || echo 0
}

# Build context bar from token counts
# Args: $1=initial_tokens (cache_read+cache_create), $2=ours_tokens (input+output)
# Output: colored bar string with shade density for smooth growth
mk_ctx_bar() {
  local initial=${1:-0} ours=${2:-0}
  local usable=$BAR_USABLE reserved=$BAR_RESERVED
  local total=$((initial + ours))
  local quarters=$((usable * 4))  # Total 1/4ths available (36 for 9 chars)

  # Convert tokens to quarters (more granular than chars)
  local init_quarters=0 ours_quarters=0
  if ((initial > 0)); then
    init_quarters=$(( (initial * quarters + CTX_USABLE - 1) / CTX_USABLE ))
    ((init_quarters > quarters)) && init_quarters=$quarters
  fi
  if ((ours > 0)); then
    ours_quarters=$(( (ours * quarters + CTX_USABLE - 1) / CTX_USABLE ))
    ((ours_quarters > quarters - init_quarters)) && ours_quarters=$((quarters - init_quarters))
  fi
  local free_quarters=$((quarters - init_quarters - ours_quarters))
  ((free_quarters < 0)) && free_quarters=0

  # Build bar with shade density
  local init_bar="" ours_bar="" free_bar="" res_bar=""

  # Initial segment (cyan) - use ▓ for full, shades for partial
  local init_full=$((init_quarters / 4)) init_frac=$((init_quarters % 4))
  ((init_full > 0)) && init_bar=$(printf '▓%.0s' $(seq 1 $init_full))
  ((init_frac > 0)) && init_bar+="${SHADE_BLOCKS[$init_frac]}"

  # Ours segment (green) - shade density for smooth growth
  local ours_full=$((ours_quarters / 4)) ours_frac=$((ours_quarters % 4))
  ((ours_full > 0)) && ours_bar=$(printf '█%.0s' $(seq 1 $ours_full))
  ((ours_frac > 0)) && ours_bar+="${SHADE_BLOCKS[$ours_frac]}"

  # Free segment (dim) - use ░ for full chars
  local free_full=$((free_quarters / 4))
  ((free_full > 0)) && free_bar=$(printf '░%.0s' $(seq 1 $free_full))

  # Reserved segment (always full chars)
  ((reserved > 0)) && res_bar=$(printf '▒%.0s' $(seq 1 $reserved))

  # Color based on total usage percentage
  local pct=$((total * 100 / CTX_WINDOW))
  local ours_color="$G"
  ((pct >= 60)) && ours_color="$Y"
  ((pct >= 80)) && ours_color="$R"
  ((pct >= WARN_PCT && pct < 80)) && ours_color="$O"

  echo "${C}${init_bar}${Z}${ours_color}${ours_bar}${Z}${D}${free_bar}${Z}${Y}${res_bar}${Z}"
}

# Generic threshold color: val, warn_threshold, crit_threshold
thresh_col() {
  local v=${1%.*} w=${2:-60} c=${3:-80}
  [[ -z "$v" ]] && v=0
  ((v >= c)) && echo "$R" || { ((v >= w)) && echo "$Y" || echo "$G"; }
}

hr_12() {
  local h=$1; [[ -z "$h" ]] && echo "?" && return
  ((h==0)) && echo "12am" && return
  ((h<12)) && echo "${h}am" && return
  ((h==12)) && echo "12pm" && return
  echo "$((h-12))pm"
}

# ==================== INPUT PARSING (SINGLE JQ) ====================
# Use "_" placeholder for empty fields to handle consecutive tabs in TSV
input_json=$(cat)
IFS=$'\t' read -r model_id cwd used_pct transcript_path lines_added lines_removed <<< \
  $(echo "$input_json" | jq -r '[.model.id//"_", .workspace.current_dir//"_", .context_window.used_percentage//"_", .transcript_path//"_", .cost.total_lines_added//0, .cost.total_lines_removed//0] | @tsv')
# Convert placeholders back to empty strings
[[ "$model_id" == "_" ]] && model_id=""
[[ "$cwd" == "_" ]] && cwd=""
[[ "$used_pct" == "_" ]] && used_pct=""
[[ "$transcript_path" == "_" ]] && transcript_path=""
[[ "$lines_added" == "_" ]] && lines_added=0
[[ "$lines_removed" == "_" ]] && lines_removed=0

# Model short name
model=""
case "$model_id" in *opus*) model="opus";; *sonnet*) model="sonnet";; *haiku*) model="haiku";; *) model="${model_id#claude-}"; model="${model%%-*}";; esac

user=$(whoami)
host=$(hostname -s)

# Abbreviate path
abbrev="$cwd"
[[ "$cwd" == "$HOME"* ]] && abbrev="~${cwd#$HOME}"
IFS='/' read -ra parts <<< "$abbrev"
if ((${#parts[@]} > 4)); then
  abbrev="${parts[0]}/.../$(basename "$(dirname "$cwd")")/$(basename "$cwd")"
fi

# ==================== GIT INFO (BATCHED) ====================
git_info=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  git_status=$(git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null)

  # Single awk call to extract branch and ahead/behind (DRY)
  read -r branch ahead behind <<< $(echo "$git_status" | awk '
    /^# branch.head/ {br=$3}
    /^# branch.ab/ {gsub(/[+-]/,"",$3); gsub(/[+-]/,"",$4); ah=$3; bh=$4}
    END {print br, ah+0, bh+0}
  ')
  [[ -z "$branch" ]] && branch=$(git rev-parse --short HEAD 2>/dev/null)
  ab_info=""; ((ahead+behind > 0)) && ab_info=" {$((ahead+behind))}"

  # Count staged/unstaged/untracked - marian style (single pass)
  staged=0 unstaged=0 untracked=0
  while IFS= read -r line; do
    case "$line" in
      "? "*) ((untracked++)) ;;
      [12]\ *) xy="${line:2:2}"
        [[ "${xy:0:1}" != "." ]] && ((staged++))
        [[ "${xy:1:1}" != "." ]] && ((unstaged++)) ;;
    esac
  done <<< "$git_status"

  # Build [±] indicator (marian style)
  ct="" status="${G}✓${Z}"
  ((staged > 0 && unstaged > 0)) && ct="±"
  ((staged > 0 && unstaged == 0)) && ct="+"
  ((staged == 0 && unstaged > 0)) && ct="!"
  ((untracked > 0)) && [[ -z "$ct" ]] && ct="?"
  [[ -n "$ct" ]] && status="${Y}✗${Z}"
  change_ind=""; [[ -n "$ct" ]] && change_ind="[${Y}${ct}${Z}]"

  # File counts (S:n U:n ?:n)
  fc=""
  ((staged > 0)) && fc+="${G}S:${staged}${Z} "
  ((unstaged > 0)) && fc+="${Y}U:${unstaged}${Z} "
  ((untracked > 0)) && fc+="${R}?:${untracked}${Z} "

  # Diff stats (+lines/-lines) - only if changes exist
  diff=""
  if ((staged + unstaged > 0)); then
    read -r ins del <<< $(git --no-optional-locks diff --numstat HEAD 2>/dev/null | awk '{i+=$1;d+=$2}END{print i+0,d+0}')
    ((ins > 0)) && diff=" {${G}+${ins}${Z}"
    ((del > 0)) && { [[ -n "$diff" ]] && diff+="/${R}-${del}${Z}}" || diff=" {${R}-${del}${Z}}"; }
    ((ins > 0 && del == 0)) && diff+="}"
  fi

  # Combine: [±][branch {ahead} S:n U:n {+ins/-del} ✓/✗]
  git_info="${change_ind}[${G}${branch}${ab_info}${Z} ${fc% }${diff} ${status}]"
fi

# ==================== STATS FILE (SINGLE JQ) ====================
stats_file="$HOME/.claude/stats-cache.json"

# Defaults
total_in=0 total_out=0 cache_read=0 total_msg=0 total_sess=0 peak_hr="" first_date=""
total_cost_accurate=0 longest_dur=0 longest_msgs=0 model_breakdown=""

if [[ -f "$stats_file" ]]; then
  read -r total_in total_out cache_read total_msg total_sess peak_hr first_date \
    total_cost_accurate longest_dur longest_msgs model_breakdown <<< \
    $(jq -r '
      # Total: accurate per-model costs INCLUDING cache tokens
      # Rates from Anthropic docs (Jan 2026): https://platform.claude.com/docs/en/about-claude/pricing
      # Opus 4.5: $5/$25, Sonnet 4.5: $3/$15, Haiku 4.5: $1/$5
      # Cache: read=0.1x input, write=1.25x input
      (.modelUsage | to_entries | map(
        (.key | if contains("opus-4-5") then {ip:5, op:25, cr:0.50, cw:6.25}
                elif contains("sonnet-4-5") then {ip:3, op:15, cr:0.30, cw:3.75}
                elif contains("haiku-4-5") then {ip:1, op:5, cr:0.10, cw:1.25}
                elif contains("haiku-3-5") then {ip:0.80, op:4, cr:0.08, cw:1}
                elif contains("opus") then {ip:15, op:75, cr:1.50, cw:18.75}
                elif contains("sonnet") then {ip:3, op:15, cr:0.30, cw:3.75}
                elif contains("haiku") then {ip:0.25, op:1.25, cr:0.03, cw:0.30}
                else {ip:3, op:15, cr:0.30, cw:3.75} end) as $r |
        (((.value.inputTokens // 0) * $r.ip) +
         ((.value.outputTokens // 0) * $r.op) +
         ((.value.cacheReadInputTokens // 0) * $r.cr) +
         ((.value.cacheCreationInputTokens // 0) * $r.cw)) / 1000000
      ) | add // 0) as $tc |

      # Model breakdown: calculate % of total cost per model (including cache)
      (.modelUsage | to_entries | map(
        (.key | if contains("opus-4-5") then {n:"O",ip:5,op:25,cr:0.50,cw:6.25}
                elif contains("sonnet-4-5") then {n:"S",ip:3,op:15,cr:0.30,cw:3.75}
                elif contains("haiku-4-5") then {n:"H",ip:1,op:5,cr:0.10,cw:1.25}
                elif contains("haiku-3-5") then {n:"H",ip:0.80,op:4,cr:0.08,cw:1}
                elif contains("opus") then {n:"O",ip:15,op:75,cr:1.50,cw:18.75}
                elif contains("sonnet") then {n:"S",ip:3,op:15,cr:0.30,cw:3.75}
                elif contains("haiku") then {n:"H",ip:0.25,op:1.25,cr:0.03,cw:0.30}
                else {n:"?",ip:3,op:15,cr:0.30,cw:3.75} end) as $r |
        {name: $r.n, cost: ((((.value.inputTokens//0)*$r.ip) +
                            ((.value.outputTokens//0)*$r.op) +
                            ((.value.cacheReadInputTokens//0)*$r.cr) +
                            ((.value.cacheCreationInputTokens//0)*$r.cw))/1000000)}
      ) | if $tc > 0 then map("\(.name):\(.cost/$tc*100|floor)%") | join(" ") else "" end) as $mb |

      [
        (.modelUsage | to_entries | map(.value.inputTokens//0) | add // 0),
        (.modelUsage | to_entries | map(.value.outputTokens//0) | add // 0),
        (.modelUsage | to_entries | map(.value.cacheReadInputTokens//0) | add // 0),
        (.totalMessages // 0), (.totalSessions // 0),
        (.hourCounts | to_entries | max_by(.value) | .key // ""),
        (.dailyActivity | sort_by(.date) | .[0].date // ""),
        $tc,
        ((.longestSession.duration // 0) / 1000 | floor),  # Convert ms to seconds
        (.longestSession.messageCount // 0),
        $mb
      ] | @tsv
    ' "$stats_file" 2>/dev/null)
fi

# ==================== SESSION STATS ====================
session_id=""
[[ -n "$transcript_path" ]] && session_id=$(basename "$transcript_path" .jsonl | cut -c1-8)

sess_dur="0m"
tool_count=0
sess_msg_count=0
initial_tokens=0
ours_tokens=0
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
  first_ts=$(head -20 "$transcript_path" | jq -r 'select(.timestamp) | .timestamp' 2>/dev/null | head -1)
  last_ts=$(tail -50 "$transcript_path" | jq -r 'select(.timestamp) | .timestamp' 2>/dev/null | tail -1)
  if [[ -n "$first_ts" && -n "$last_ts" ]]; then
    first_ep=$(date_to_epoch "$first_ts")
    last_ep=$(date_to_epoch "$last_ts")
    ((first_ep > 0 && last_ep > 0)) && sess_dur=$(fmt_dur $((last_ep - first_ep)))
  fi
  tool_count=$(grep -c '"tool_use' "$transcript_path" 2>/dev/null || echo 0)
  sess_msg_count=$(grep -c '"type":"user"' "$transcript_path" 2>/dev/null || echo 0)

  # Get latest usage entry for current state
  latest_usage=$(tail -100 "$transcript_path" | jq -s '[.[] | .message.usage // empty] | .[-1]' 2>/dev/null)
  if [[ -n "$latest_usage" && "$latest_usage" != "null" ]]; then
    initial_tokens=$(get_initial_tokens "$latest_usage")
    ours_tokens=$(get_ours_tokens "$latest_usage")
  fi

  # Calculate session cost from JSONL usage (same rate pattern as TOTAL)
  # Rates from Anthropic docs - same as stats-cache calculation for DRY
  sess_cost_from_jsonl=$(jq -rs --arg model "$model_id" '
    [.[] | .message.usage // empty] |
    ($model | if contains("opus-4-5") then {ip:5, op:25, cr:0.50, cw:6.25}
              elif contains("sonnet-4-5") then {ip:3, op:15, cr:0.30, cw:3.75}
              elif contains("haiku-4-5") then {ip:1, op:5, cr:0.10, cw:1.25}
              elif contains("haiku-3-5") then {ip:0.80, op:4, cr:0.08, cw:1}
              elif contains("opus") then {ip:15, op:75, cr:1.50, cw:18.75}
              elif contains("sonnet") then {ip:3, op:15, cr:0.30, cw:3.75}
              elif contains("haiku") then {ip:0.25, op:1.25, cr:0.03, cw:0.30}
              else {ip:3, op:15, cr:0.30, cw:3.75} end) as $r |
    ((map(.input_tokens // 0) | add) * $r.ip +
     (map(.output_tokens // 0) | add) * $r.op +
     (map(.cache_read_input_tokens // 0) | add) * $r.cr +
     (map(.cache_creation_input_tokens // 0) | add) * $r.cw) / 1000000
  ' "$transcript_path" 2>/dev/null)
fi

# Session cost from JSONL (includes all token types including cache)
sess_cost=$(printf "%.2f" "${sess_cost_from_jsonl:-0}")

# ==================== CALCULATIONS ====================
total_tok=$((total_in + total_out))

# Total cost (use accurate per-model calculation from jq)
total_cost=$(printf "%.2f" "$total_cost_accurate")

# Cache rate
cache_rate=0
((total_in + cache_read > 0)) && cache_rate=$(bc -l <<< "100 * $cache_read / ($cache_read + $total_in)" | xargs printf "%.0f")

# Avg cost
avg_cost="0.00"
((total_sess > 0)) && avg_cost=$(bc -l <<< "$total_cost / $total_sess" | xargs printf "%.2f")

# Format dates
first_fmt=""
[[ -n "$first_date" && "$first_date" != "null" ]] && first_fmt=$(date_fmt "$first_date")
peak_fmt=$(hr_12 "$peak_hr")

# ==================== BUILD OUTPUT (Mairan Colors) ====================
# Line 1: [user][host][git][path]
line1="[${G}${user}${Z}][${O}${host}${Z}]${git_info}[${G}${abbrev}${Z}]"

# Line 2: [SESSION][model ctx][tokens][cost][duration][tools]
# Build context bar from token counts
ctx_bar=""
if [[ -n "$model" ]]; then
  # Use JSONL tokens if available, otherwise derive from input JSON percentage
  if ((initial_tokens > 0 || ours_tokens > 0)); then
    bar=$(mk_ctx_bar "$initial_tokens" "$ours_tokens")
  elif [[ -n "$used_pct" && "$used_pct" != "0" ]]; then
    # Fallback: treat all as initial (no JSONL data yet)
    # This handles race condition on first message before JSONL is written
    initial_tokens=$((${used_pct%.*} * CTX_WINDOW / 100))
    bar=$(mk_ctx_bar "$initial_tokens" 0)
  else
    bar=$(mk_ctx_bar 0 0)
  fi

  # Calculate display percentage
  total_tokens=$((initial_tokens + ours_tokens))
  pct=0
  ((total_tokens > 0)) && pct=$((total_tokens * 100 / CTX_WINDOW))
  [[ -n "$used_pct" && "$used_pct" != "0" ]] && pct=${used_pct%.*}

  warn_icon=""
  ((pct >= WARN_PCT)) && warn_icon="⚡"
  ctx_bar="[${P}${model}${Z} ctx:${bar} $(thresh_col "$pct" 60 80)${warn_icon}${pct}%${Z}]"
fi

# Format lines changed for session
lines_diff=""
if ((lines_added > 0 || lines_removed > 0)); then
  lines_diff="[${G}+${lines_added}${Z}/${R}-${lines_removed}${Z}]"
fi

# Line 2: SESSION with msg/tools, cost, duration, lines changed
line2="[${O}SESSION ${G}${session_id}${Z}]${ctx_bar}[${G}${sess_msg_count}${Z} ${D}msg${Z} | ${G}${tool_count}${Z} ${D}tools${Z}][$(thresh_col "$sess_cost" 1 10)\$${sess_cost}${Z}][${G}${sess_dur}${Z}]${lines_diff}"

# Line 3: [TOTAL][SINCE] - cleaned up
line3="[${O}TOTAL:${Z} ${G}$(fmt_tok "$total_tok")${Z} ${D}tok${Z} | ${G}$(fmt_tok "$total_msg")${Z} ${D}msg${Z} | ${G}${total_sess}${Z} ${D}sess${Z} | $(thresh_col "$total_cost" 100 500)\$${total_cost}${Z} | ${G}${cache_rate}%${Z} ${D}cached${Z}]"
line3+="[${O}SINCE:${Z} ${G}${first_fmt}${Z} | ${D}avg:${Z} ${R}\$${avg_cost}${Z}${D}/sess${Z}]"

# Line 4: RECORDS - longest session, peak hour, model mix
longest_rec=""
((longest_dur > 0)) && longest_rec="${D}longest:${Z} ${G}$(fmt_dur "$longest_dur")${Z}/${G}${longest_msgs}${Z}${D}msg${Z}"
peak_rec="${D}peak:${Z} ${G}${peak_fmt}${Z}"
model_rec=""
[[ -n "$model_breakdown" ]] && model_rec="${D}mix:${Z} ${P}${model_breakdown}${Z}"
line4="[${O}RECORDS:${Z} ${longest_rec} | ${peak_rec} | ${model_rec}]"

# ==================== OUTPUT ====================
printf "%b\n%b\n%b\n%b" "$line1" "$line2" "$line3" "$line4"
