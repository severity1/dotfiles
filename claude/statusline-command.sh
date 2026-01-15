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
Z="\033[0m"     # Reset

# ==================== CONSTANTS ====================
BAR_LEN=12                    # Progress bar character width
WARN_PCT=67                   # Context warning threshold (before autocompact zone)
CTX_WINDOW_DEFAULT=200000     # Default context window size (Opus/Sonnet)

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

mk_bar() {
  # BAR_LEN-char bar: used (█) | free (░) | reserved/autocompact (▒)
  # Autocompact buffer is ~22.5% = 3 chars reserved at the end
  # Returns: "used_chars free_chars reserved_chars" for caller to colorize
  local p=${1%.*} len=$BAR_LEN; [[ -z "$p" ]] && p=0
  local used=$((p*len/100))
  ((used > len)) && used=$len
  ((used < 0)) && used=0
  local reserved=3  # ~22.5% autocompact buffer (3/12 = 25%)
  local free=$((len-used-reserved))
  ((free < 0)) && free=0
  # If usage is high, it eats into reserved space
  ((used > len-reserved)) && reserved=$((len-used)) && free=0
  echo "$used $free $reserved"
}

mk_bar_colored() {
  local p=$1 warn=$WARN_PCT
  read -r used free reserved <<< $(mk_bar "$p")
  # Build bar segments using printf repeat (DRY)
  local used_bar=$(printf '█%.0s' $(seq 1 $used 2>/dev/null))
  local free_bar=$(printf '░%.0s' $(seq 1 $free 2>/dev/null))
  local res_bar=$(printf '▒%.0s' $(seq 1 $reserved 2>/dev/null))
  # Color based on threshold: warning zone (67-79%) = orange, critical (>=80) = red
  local uc=$(thresh_col "$p" 60 80)
  local pi=${p%.*}  # Strip decimal for arithmetic
  ((pi >= warn && pi < 80)) && uc="$O"
  # Combine with colors
  echo "${uc}${used_bar}${Z}${D}${free_bar}${Z}${Y}${res_bar}${Z}"
}

# Split bar showing messages (jsonl) and system overhead (difference)
# Args: $1=total_pct (CLI), $2=jsonl_pct (messages)
mk_bar_split() {
  local total=${1%.*} jsonl=${2%.*} len=$BAR_LEN warn=$WARN_PCT
  [[ -z "$total" ]] && total=0
  [[ -z "$jsonl" ]] && jsonl=0
  ((jsonl > total)) && jsonl=$total

  # Reuse mk_bar for base calculation (DRY)
  read -r total_chars free reserved <<< $(mk_bar "$total")

  # Split used portion into messages and system overhead
  local msg_chars=$((jsonl * len / 100))
  local sys_chars=$((total_chars - msg_chars))
  ((msg_chars < 0)) && msg_chars=0
  ((sys_chars < 0)) && sys_chars=0

  # Build bar segments
  local msg_bar=$(printf '█%.0s' $(seq 1 $msg_chars 2>/dev/null))
  local sys_bar=$(printf '▓%.0s' $(seq 1 $sys_chars 2>/dev/null))
  local free_bar=$(printf '░%.0s' $(seq 1 $free 2>/dev/null))
  local res_bar=$(printf '▒%.0s' $(seq 1 $reserved 2>/dev/null))

  # Colors: messages=green (threshold), system=cyan, free=dim, reserved=yellow
  local mc=$(thresh_col "$total" 60 80)
  ((total >= warn && total < 80)) && mc="$O"
  echo "${mc}${msg_bar}${Z}${C}${sys_bar}${Z}${D}${free_bar}${Z}${Y}${res_bar}${Z}"
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

get_ctx_window() {
  # All current Claude models have 200k context window
  # Kept as function for future model-specific values
  echo $CTX_WINDOW_DEFAULT
}

# Build context bar with optional split view - sets _ctx_bar global
# Args: $1=pct (display %), $2=jsonl_pct (optional, for split bar)
build_ctx_bar() {
  local pct=$1 jsonl_pct=$2 bar warn_icon=""
  ((${pct%.*} >= WARN_PCT)) && warn_icon="⚡"
  if [[ -n "$jsonl_pct" ]]; then
    bar=$(mk_bar_split "$pct" "$jsonl_pct")
  else
    bar=$(mk_bar_colored "$pct")
  fi
  _ctx_bar="[${P}${model}${Z} ctx:${bar} $(thresh_col "$pct" 60 80)${warn_icon}${pct}%${Z}]"
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
ctx_from_jsonl=""
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

  # Calculate accurate context % from latest JSONL usage entry
  # Formula: (cache_read + cache_create + input + output) / context_window * 100
  ctx_tokens=$(tail -100 "$transcript_path" | jq -r 'select(.message.usage) | (.message.usage.cache_read_input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0) + (.message.usage.input_tokens // 0) + (.message.usage.output_tokens // 0)' 2>/dev/null | tail -1)
  if [[ -n "$ctx_tokens" && "$ctx_tokens" -gt 0 ]]; then
    ctx_window=$(get_ctx_window "$model_id")
    ctx_from_jsonl=$(bc -l <<< "scale=1; $ctx_tokens * 100 / $ctx_window")
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
_ctx_bar=""
if [[ -n "$used_pct" && "$used_pct" != "0" && -n "$ctx_from_jsonl" ]]; then
  build_ctx_bar "$used_pct" "$ctx_from_jsonl"  # Split bar
elif [[ -n "$used_pct" && "$used_pct" != "0" ]]; then
  build_ctx_bar "$used_pct"
elif [[ -n "$ctx_from_jsonl" ]]; then
  build_ctx_bar "$ctx_from_jsonl"
elif [[ -n "$model" ]]; then
  _ctx_bar="[${P}${model}${Z}]"
fi
ctx_bar="$_ctx_bar"

# Format lines changed for session
lines_diff=""
if ((lines_added > 0 || lines_removed > 0)); then
  lines_diff="[${G}+${lines_added}${Z}/${R}-${lines_removed}${Z}]"
fi

# Line 2: SESSION with msg/tools, cost, duration, lines changed
line2="[${O}SESSION ${G}${session_id}${Z}]${ctx_bar}[${G}${sess_msg_count}${Z} ${D}msg${Z} | ${Y}${tool_count}${Z} ${D}tools${Z}][$(thresh_col "$sess_cost" 1 10)\$${sess_cost}${Z}][${Y}${sess_dur}${Z}]${lines_diff}"

# Line 3: [TOTAL][SINCE] - cleaned up
line3="[${O}TOTAL:${Z} ${G}$(fmt_tok "$total_tok")${Z} ${D}tok${Z} | ${G}$(fmt_tok "$total_msg")${Z} ${D}msg${Z} | ${G}${total_sess}${Z} ${D}sess${Z} | $(thresh_col "$total_cost" 100 500)\$${total_cost}${Z} | ${G}${cache_rate}%${Z} ${D}cached${Z}]"
line3+="[${O}SINCE:${Z} ${G}${first_fmt}${Z} | ${G}avg: \$${avg_cost}${Z}${D}/sess${Z}]"

# Line 4: RECORDS - longest session, peak hour, model mix
longest_rec=""
((longest_dur > 0)) && longest_rec="${D}longest:${Z} ${G}$(fmt_dur "$longest_dur")${Z}/${G}${longest_msgs}${Z}${D}msg${Z}"
peak_rec="${D}peak:${Z} ${G}${peak_fmt}${Z}"
model_rec=""
[[ -n "$model_breakdown" ]] && model_rec="${D}mix:${Z} ${P}${model_breakdown}${Z}"
line4="[${O}RECORDS:${Z} ${longest_rec} | ${peak_rec} | ${model_rec}]"

# ==================== OUTPUT ====================
printf "%b\n%b\n%b\n%b" "$line1" "$line2" "$line3" "$line4"
