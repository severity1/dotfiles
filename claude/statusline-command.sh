#!/bin/bash
# Claude Code statusline - Optimized version (<100ms target)
# Line 1: [user][host][branch info][path]
# Line 2: [SESSION id][model ctx%][tokens][cost][duration][tools]
# Line 3: [TODAY: ...][WEEK: ...]
# Line 4: [TOTAL: ...][SINCE: ... | peak: ... | avg: ...]

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
  # 12-char bar: used (█) | free (░) | reserved/autocompact (▒)
  # Autocompact buffer is ~22.5% = 3 chars reserved at the end
  # Returns: "used_chars free_chars reserved_chars" for caller to colorize
  local p=${1%.*} len=12; [[ -z "$p" ]] && p=0
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
  local p=$1 warn=67  # 10% before reserved space triggers warning
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
  local total=${1%.*} jsonl=${2%.*} len=12 warn=67
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

calc_cost() {
  local m=$1 i=$2 o=$3 ip=3 op=15
  case "$m" in opus) ip=15;op=75;; sonnet) ip=3;op=15;; haiku) ip=0.25;op=1.25;; esac
  bc -l <<< "scale=2; ($i * $ip + $o * $op) / 1000000" | xargs printf "%.2f"
}

hr_12() {
  local h=$1; [[ -z "$h" ]] && echo "?" && return
  ((h==0)) && echo "12am" && return
  ((h<12)) && echo "${h}am" && return
  ((h==12)) && echo "12pm" && return
  echo "$((h-12))pm"
}

# Build context bar with optional split view - sets _ctx_bar global
# Args: $1=pct (display %), $2=jsonl_pct (optional, for split bar)
build_ctx_bar() {
  local pct=$1 jsonl_pct=$2 bar warn_icon=""
  ((${pct%.*} >= 67)) && warn_icon="⚡"
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
IFS=$'\t' read -r model_id cwd used_pct sess_in sess_out transcript_path <<< \
  $(echo "$input_json" | jq -r '[.model.id//"_", .workspace.current_dir//"_", .context_window.used_percentage//"_", .context_window.total_input_tokens//0, .context_window.total_output_tokens//0, .transcript_path//"_"] | @tsv')
# Convert placeholders back to empty strings
[[ "$model_id" == "_" ]] && model_id=""
[[ "$cwd" == "_" ]] && cwd=""
[[ "$used_pct" == "_" ]] && used_pct=""
[[ "$transcript_path" == "_" ]] && transcript_path=""

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
today=$(date +%Y-%m-%d)

# Defaults
total_in=0 total_out=0 cache_read=0 total_msg=0 total_sess=0 peak_hr="" first_date=""
week_tok=0 week_msg=0 week_tools=0 week_sess=0
today_tok=0 today_msg=0 today_tools=0 today_sess=0

if [[ -f "$stats_file" ]]; then
  read -r total_in total_out cache_read total_msg total_sess peak_hr first_date \
    week_tok week_msg week_tools week_sess today_tok today_msg today_tools today_sess <<< \
    $(jq -r --arg today "$today" '
      [(range(7) | (now - . * 86400) | strftime("%Y-%m-%d"))] as $wk |
      ([.dailyModelTokens[] | select(.date as $d | $wk | index($d)) | .tokensByModel | to_entries | map(.value) | add] | add // 0) as $wt |
      ([.dailyActivity[] | select(.date as $d | $wk | index($d))] | {m:(map(.messageCount//0)|add//0), t:(map(.toolCallCount//0)|add//0), s:(map(.sessionCount//0)|add//0)}) as $wa |
      ([.dailyModelTokens[] | select(.date==$today) | .tokensByModel | to_entries | map(.value) | add] | add // 0) as $tt |
      (.dailyActivity[] | select(.date==$today) // {}) as $ta |
      [
        (.modelUsage | to_entries | map(.value.inputTokens//0) | add // 0),
        (.modelUsage | to_entries | map(.value.outputTokens//0) | add // 0),
        (.modelUsage | to_entries | map(.value.cacheReadInputTokens//0) | add // 0),
        (.totalMessages // 0), (.totalSessions // 0),
        (.hourCounts | to_entries | max_by(.value) | .key // ""),
        (.dailyActivity | sort_by(.date) | .[0].date // ""),
        $wt, $wa.m, $wa.t, $wa.s,
        $tt, ($ta.messageCount//0), ($ta.toolCallCount//0), ($ta.sessionCount//0)
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
    first_ep=$(date -d "$first_ts" +%s 2>/dev/null || echo 0)
    last_ep=$(date -d "$last_ts" +%s 2>/dev/null || echo 0)
    ((first_ep > 0 && last_ep > 0)) && sess_dur=$(fmt_dur $((last_ep - first_ep)))
  fi
  tool_count=$(grep -c '"tool_use' "$transcript_path" 2>/dev/null | tr -d '\n' || echo 0)
  sess_msg_count=$(grep -c '"type":"user"' "$transcript_path" 2>/dev/null | tr -d '\n' || echo 0)

  # Calculate accurate context % from latest JSONL usage entry
  # Formula: (cache_read + cache_create + input + output) / context_window * 100
  ctx_tokens=$(tail -100 "$transcript_path" | jq -r 'select(.message.usage) | (.message.usage.cache_read_input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0) + (.message.usage.input_tokens // 0) + (.message.usage.output_tokens // 0)' 2>/dev/null | tail -1)
  if [[ -n "$ctx_tokens" && "$ctx_tokens" -gt 0 ]]; then
    ctx_window=200000  # Opus/Sonnet context window
    ctx_from_jsonl=$(bc -l <<< "scale=1; $ctx_tokens * 100 / $ctx_window")
  fi
fi

sess_cost=$(calc_cost "$model" "$sess_in" "$sess_out")

# ==================== CALCULATIONS ====================
total_tok=$((total_in + total_out))
inp_ratio="0.30"
((total_tok > 0)) && inp_ratio=$(bc -l <<< "$total_in / $total_tok" | xargs printf "%.4f")

# Today fallback - use session stats when cache doesn't have today's data
today_cached=true
if ((today_tok == 0)); then
  today_cached=false
  today_tok=$((sess_in + sess_out))
  today_msg=$sess_msg_count; today_tools=$tool_count
  # Count sessions modified today using find with -printf (fast, single process)
  today_start=$(date -d "today 00:00" +%s 2>/dev/null || echo 0)
  today_sess=$(find ~/.claude/projects -maxdepth 2 -name "*.jsonl" -type f -printf '%T@\n' 2>/dev/null | awk -v ts="$today_start" '$1 >= ts {c++} END {print c+0}')
  ((today_sess == 0)) && today_sess=1
fi
today_in=$(bc -l <<< "$today_tok * $inp_ratio" | xargs printf "%.0f")
today_out=$((today_tok - today_in))
today_cost=$(calc_cost "$model" "$today_in" "$today_out")

# Week cost
week_in=$(bc -l <<< "$week_tok * $inp_ratio" | xargs printf "%.0f")
week_out=$((week_tok - week_in))
week_cost=$(calc_cost "$model" "$week_in" "$week_out")

# Total cost
total_cost=$(calc_cost "$model" "$total_in" "$total_out")

# Cache rate
cache_rate=0
((total_in + cache_read > 0)) && cache_rate=$(bc -l <<< "100 * $cache_read / ($cache_read + $total_in)" | xargs printf "%.0f")

# Avg cost
avg_cost="0.00"
((total_sess > 0)) && avg_cost=$(bc -l <<< "$total_cost / $total_sess" | xargs printf "%.2f")

# Format dates
first_fmt=""
[[ -n "$first_date" && "$first_date" != "null" ]] && first_fmt=$(date -d "$first_date" "+%b %d, %Y" 2>/dev/null || echo "$first_date")
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

line2="[${O}SESSION ${G}${session_id}${Z}]${ctx_bar}[${G}$(fmt_tok "$sess_in")${Z} ${D}in${Z} | ${G}$(fmt_tok "$sess_out")${Z} ${D}out${Z} | $(thresh_col "$sess_cost" 1 10)\$${sess_cost}${Z}][${Y}${sess_dur}${Z}][${Y}${tool_count}${Z} ${D}tools${Z}]"

# Line 3: [TODAY][WEEK]
today_label="TODAY"; $today_cached || today_label="TODAY*"
tc=$(thresh_col "$today_msg" 20 50)
wc=$(thresh_col "$week_msg" 100 300)

line3="[${O}${today_label}:${Z} ${G}$(fmt_tok "$today_tok")${Z} ${D}tok${Z} | ${tc}${today_msg}${Z} ${D}msg${Z} | ${G}$(fmt_tok "$today_tools")${Z} ${D}tools${Z} | ${G}${today_sess}${Z} ${D}sess${Z} | $(thresh_col "$today_cost" 1 10)\$${today_cost}${Z}]"
line3+="[${O}WEEK:${Z} ${G}$(fmt_tok "$week_tok")${Z} ${D}tok${Z} | ${wc}${week_msg}${Z} ${D}msg${Z} | ${G}$(fmt_tok "$week_tools")${Z} ${D}tools${Z} | ${G}${week_sess}${Z} ${D}sess${Z} | $(thresh_col "$week_cost" 10 50)\$${week_cost}${Z}]"

# Line 4: [TOTAL][SINCE]
line4="[${O}TOTAL:${Z} ${G}$(fmt_tok "$total_tok")${Z} ${D}tok${Z} | ${G}$(fmt_tok "$total_msg")${Z} ${D}msg${Z} | ${G}${total_sess}${Z} ${D}sess${Z} | $(thresh_col "$total_cost" 100 500)\$${total_cost}${Z} | ${G}${cache_rate}%${Z} ${D}cached${Z}]"
line4+="[${O}SINCE:${Z} ${G}${first_fmt}${Z} | ${Y}peak:${Z} ${G}${peak_fmt}${Z} | ${G}avg: \$${avg_cost}${Z}${D}/sess${Z}]"

# ==================== OUTPUT ====================
printf "%b\n%b\n%b\n%b" "$line1" "$line2" "$line3" "$line4"
