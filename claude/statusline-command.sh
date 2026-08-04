#!/usr/bin/env bash
# Claude Code statusline.
#
#   [opus @ 3b8ed793][~/Workspace/acme/api-gateway][±][main S:1 +2/-0 ✗]
#   [7% of 1M · 5.3M↑ 11k↓ · 97% cached (+1k w) · 48 tools/5 · 3 skills · 6 turns]
#   [34% 5h ↻3h 14m · 12% 7d · $13.23 · 1h 16m (37% wait) · +342/-517]
#
# Line 1 always renders. Lines 2-3 are session instrumentation, split by what
# each one measures: line 2 is the session itself (how large the conversation
# has grown and how much work was done), line 3 is what that consumed. Each
# group renders only when it has content, and every field within a group is
# independently conditional, so a fresh session shows one short line and a long
# one fills out.
# Fields that stay silent unless they have something to say: prompt-cache hit
# rate, skill/MCP/subagent counts, and the mode flags (fast, think:off, 200k+,
# subagent name).
#
# Widths target a 120-column budget: a heavy session (every field populated,
# six-figure counts) measures 105 / 93. Splitting the other way - activity onto
# the budget line instead - would reach 150 and blow the budget, so the join
# side is forced rather than chosen. The budget is a design constraint
# rather than a runtime check, because the width cannot actually be read here -
# there is no tty, COLUMNS is unset, and `tput cols` reports terminfo's
# 80-column default instead of a measurement.
#
# The budget field adapts to billing mode rather than being configured for it.
# API billing reports dollars and a null rate_limits. A subscription reports
# both: the 5h / 7d windows AND a non-zero total_cost_usd - verified against a
# live subscription payload, where $0.69 appeared beside 1% 5h / 42% 7d. That
# dollar figure is presumably a notional equivalent rather than an amount
# actually charged, though that has not been confirmed. Whichever
# arrives is what renders - both if both, neither if neither - so one script
# suits either account without a flag.
#
# Line 1 fields run stable -> volatile, left to right: the model/session pair
# is fixed width, the path changes rarely, and git state changes width
# constantly. The jittiest field sits last so nothing left of it shifts.
#
# Colors follow the oh-my-bash "mairan" theme. Kept bash 3.2 compatible
# (macOS /bin/bash): no negative array subscripts, no mapfile, no assoc arrays.

# Escapes are resolved here, at definition time, so the render can use a plain
# %s and never reinterpret backslashes that appear in branch or path names.
G=$'\033[1;32m'   # green  - branch, clean mark, path, additions, healthy nums
Y=$'\033[0;33m'   # yellow - dirty state, behind-count, unstaged, warnings
R=$'\033[0;31m'   # red    - untracked, deletions, critical
P=$'\033[1;35m'   # purple - model
C=$'\033[0;36m'   # cyan   - tool/skill/mcp instrumentation
D=$'\033[0;90m'   # dim    - session id, labels, separators, units
Z=$'\033[0m'      # reset

BRANCH_MAX=30                     # middle-elide branch names past this
SEP=" ${D}·${Z} "                 # inter-field separator on line 2

# ==================== HELPERS ====================
# Integer-only formatting: spawning bc per field would cost more than the rest
# of the script combined.
fmt_tok() {
  local t=${1:-0}
  ((t < 1000))       && { printf '%s' "$t"; return; }
  ((t < 1000000))    && { printf '%dk' $((t / 1000)); return; }
  local whole frac
  if ((t < 1000000000)); then
    whole=$((t / 1000000)) frac=$(((t % 1000000) / 100000))
    ((frac)) && printf '%d.%dM' "$whole" "$frac" || printf '%dM' "$whole"
    return
  fi
  whole=$((t / 1000000000)) frac=$(((t % 1000000000) / 100000000))
  ((frac)) && printf '%d.%dB' "$whole" "$frac" || printf '%dB' "$whole"
}

fmt_dur() {   # seconds -> 3d 4h / 4h 12m / 12m
  local s=${1:-0} m=$((${1:-0} / 60)) h=$((${1:-0} / 3600)) d=$((${1:-0} / 86400))
  ((d)) && { printf '%dd %dh' "$d" $((h % 24)); return; }
  ((h)) && { printf '%dh %dm' "$h" $((m % 60)); return; }
  printf '%dm' "$m"
}

join_sep() {  # join "$@" with SEP, skipping empties
  local out="" f
  for f in "$@"; do
    [[ -z $f ]] && continue
    [[ -n $out ]] && out+=$SEP
    out+=$f
  done
  printf '%s' "$out"
}

plural() {    # count, singular -> "3 skills" / "1 skill"
  (($1 == 1)) && { printf '%s %s' "$1" "$2"; return; }
  printf '%s %ss' "$1" "$2"
}

# ==================== INPUT ====================
# One jq call, one field per line. Line-oriented reads (rather than @tsv) keep
# empty fields in position: tab is IFS-whitespace, so a tab-split read would
# silently collapse consecutive empty columns. Numerics are floored so bash
# arithmetic can consume them directly; cost keeps its decimals.
#
# NOTE: context_window.total_input_tokens is NOT a session cumulative - the
# CLI sets it from current_usage, so it mirrors the latest message only.
# Cumulative usage is summed from the transcript further down.
{ IFS= read -r model_id
  IFS= read -r cwd
  IFS= read -r session_id
  IFS= read -r transcript_path
  IFS= read -r ctx_pct
  IFS= read -r ctx_size
  IFS= read -r cache_read
  IFS= read -r cache_write
  IFS= read -r cur_in
  IFS= read -r cost_usd
  IFS= read -r dur_s
  IFS= read -r api_dur_s
  IFS= read -r added
  IFS= read -r removed
  IFS= read -r fast_mode
  IFS= read -r thinking
  IFS= read -r over_200k
  IFS= read -r agent_name
  IFS= read -r rl5_pct
  IFS= read -r rl5_left
  IFS= read -r rl7_pct
  IFS= read -r rl7_left
} <<< "$(jq -r '
    # resets_at arrives either as epoch seconds (from response headers) or as
    # an ISO-8601 string (from the persisted/OAuth path), so normalize both to
    # seconds-from-now. -1 means "not reported".
    def rl_left:
      if . == null then -1
      elif type == "number" then (. - now | floor)
      elif type == "string" then (try ((fromdateiso8601) - now | floor) catch -1)
      else -1 end;
    .model.id // "",
    .workspace.current_dir // "",
    .session_id // "",
    .transcript_path // "",
    (.context_window.used_percentage // 0 | floor),
    (.context_window.context_window_size // 0 | floor),
    (.context_window.current_usage.cache_read_input_tokens // 0 | floor),
    (.context_window.current_usage.cache_creation_input_tokens // 0 | floor),
    (.context_window.current_usage.input_tokens // 0 | floor),
    (.cost.total_cost_usd // 0),
    ((.cost.total_duration_ms // 0) / 1000 | floor),
    ((.cost.total_api_duration_ms // 0) / 1000 | floor),
    (.cost.total_lines_added // 0 | floor),
    (.cost.total_lines_removed // 0 | floor),
    (if .fast_mode then 1 else 0 end),
    (if .thinking.enabled == false then 0 else 1 end),
    (if .exceeds_200k_tokens then 1 else 0 end),
    (.agent.name // ""),
    (.rate_limits.five_hour.used_percentage // -1 | floor),
    (.rate_limits.five_hour.resets_at | rl_left),
    (.rate_limits.seven_day.used_percentage // -1 | floor),
    (.rate_limits.seven_day.resets_at | rl_left)
  ')"

# Cost arrives as a float; compare as cents so no bc/awk call is needed.
cost_cents=0
[[ $cost_usd == *[0-9]* ]] && cost_cents=$(printf '%.0f' "$(printf '%.2f' "$cost_usd")e2" 2>/dev/null || echo 0)

# A jq failure would leave these empty, and empty operands are a syntax error
# inside (( )). -1 is the "not reported" sentinel.
: "${rl5_pct:=-1}" "${rl5_left:=-1}" "${rl7_pct:=-1}" "${rl7_left:=-1}"
case $rl5_pct in ''|*[!0-9-]*) rl5_pct=-1 ;; esac
case $rl7_pct in ''|*[!0-9-]*) rl7_pct=-1 ;; esac
case $rl5_left in ''|*[!0-9-]*) rl5_left=-1 ;; esac
case $rl7_left in ''|*[!0-9-]*) rl7_left=-1 ;; esac

# ==================== MODEL + SESSION ====================
case $model_id in
  *opus*)   model="opus" ;;
  *sonnet*) model="sonnet" ;;
  *haiku*)  model="haiku" ;;
  *fable*)  model="fable" ;;
  *)        model=${model_id#claude-}; model=${model%%-*} ;;
esac

# Transcript filename is the session id when the field itself is absent.
if [[ -z $session_id && -n $transcript_path ]]; then
  session_id=${transcript_path##*/}
  session_id=${session_id%.jsonl}
fi
session=${session_id:0:8}

# Degrade cleanly when either half is missing, rather than leaving a bare "@".
if   [[ -n $model && -n $session ]]; then head_seg="[${P}${model}${Z} ${D}@ ${session}${Z}]"
elif [[ -n $model ]];                then head_seg="[${P}${model}${Z}]"
elif [[ -n $session ]];              then head_seg="[${D}${session}${Z}]"
else                                      head_seg=""
fi

# ==================== PATH ====================
# Collapse $HOME, then elide the middle of anything deeper than 4 components:
# ~/a/b/c/d/e -> ~/.../d/e
path=$cwd
# Guard on $HOME being set: unset expands to "", and every string has an
# empty prefix, which would tilde-prefix unrelated paths.
[[ -n $HOME && $cwd == "$HOME"* ]] && path="~${cwd#"$HOME"}"
IFS=/ read -ra seg <<< "$path"
if ((${#seg[@]} > 4)); then
  n=${#seg[@]}
  path="${seg[0]}/.../${seg[n-2]}/${seg[n-1]}"
fi
path_seg=""
[[ -n $path ]] && path_seg="[${G}${path}${Z}]"

# ==================== GIT ====================
# Single `status` call parsed in one pass. porcelain=v2 --branch carries the
# branch name, ahead/behind, and per-file states in the same stream, so no
# follow-up rev-parse is needed - not even when detached.
git_seg=""
git_raw=$(git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null)
if [[ -n $git_raw ]]; then
  branch="" oid="" ahead=0 behind=0 staged=0 unstaged=0 untracked=0

  while IFS= read -r line; do
    case $line in
      '# branch.oid '*)  oid=${line#'# branch.oid '} ;;
      '# branch.head '*) branch=${line#'# branch.head '} ;;
      '# branch.ab '*)   read -r _ _ a b <<< "$line"
                         ahead=${a#+} behind=${b#-} ;;
      '? '*)             ((untracked++)) ;;
      [12]' '*)          xy=${line:2:2}          # XY staged/unstaged codes
                         [[ ${xy:0:1} != . ]] && ((staged++))
                         [[ ${xy:1:1} != . ]] && ((unstaged++)) ;;
    esac
  done <<< "$git_raw"

  [[ $branch == '(detached)' ]] && branch="@${oid:0:7}"

  # Middle-elide long branch names before any color codes are attached, so
  # ${#branch} still reflects visible width.
  if ((${#branch} > BRANCH_MAX)); then
    keep_head=16
    keep_tail=$((BRANCH_MAX - keep_head - 1))   # -1 for the ellipsis itself
    branch="${branch:0:keep_head}${D}…${G}${branch:$((${#branch} - keep_tail))}"
  fi

  # Leading indicator mirrors the mairan prompt: ± both, + staged, ! unstaged,
  # ? untracked only.
  mark="${G}✓${Z}" ind="" ct=""
  if   ((staged && unstaged)); then ct="±"
  elif ((staged));            then ct="+"
  elif ((unstaged));          then ct="!"
  elif ((untracked));         then ct="?"
  fi
  [[ -n $ct ]] && { mark="${Y}✗${Z}"; ind="[${Y}${ct}${Z}]"; }

  # Assemble as an array and join once, so absent fields cost no whitespace.
  fields=("${G}${branch}${Z}")

  ab=""
  ((ahead))  && ab+="${G}↑${ahead}${Z}"
  ((behind)) && ab+="${Y}↓${behind}${Z}"
  [[ -n $ab ]] && fields+=("$ab")

  ((staged))    && fields+=("${G}S:${staged}${Z}")
  ((unstaged))  && fields+=("${Y}U:${unstaged}${Z}")
  ((untracked)) && fields+=("${R}?:${untracked}${Z}")

  # Line counts need a second git call, so only pay for it when something
  # tracked actually changed. awk's $1+0 absorbs the "-" numstat emits for
  # binary files.
  if ((staged + unstaged)); then
    read -r ins del <<< "$(git --no-optional-locks diff --numstat HEAD 2>/dev/null |
      awk '{i+=$1; d+=$2} END {print i+0, d+0}')"
    ((ins || del)) && fields+=("${G}+${ins}${Z}/${R}-${del}${Z}")
  fi

  fields+=("$mark")
  git_seg="${ind}[${fields[*]}]"   # IFS untouched above; joins on space
fi

# ==================== TRANSCRIPT AGGREGATE ====================
# One streaming jq pass over the session JSONL for the things the payload does
# not carry: cumulative token usage, and tool / skill / MCP / subagent counts.
# Tool names are collected into objects used as sets, so distinct counts come
# free. Kept to a single process - this is the only unbounded work here, and it
# grows with session length.
t_in=0 t_out=0 t_cr=0 t_cw=0 tools=0 kinds=0 skills=0 mcps=0 agents=0 turns=0
agg_cache="" agg_size=0
if [[ -r $transcript_path ]]; then
  # The scan is the only cost here that grows with session length, and the
  # statusline repaints far more often than the transcript changes. Key a cache
  # on the file's byte size: identical size means no new records, so the whole
  # jq pass can be skipped. Cheaper than being clever about byte offsets, and
  # a size collision only costs one stale repaint.
  agg_size=$(stat -f %z "$transcript_path" 2>/dev/null ||
             stat -c %s "$transcript_path" 2>/dev/null || echo 0)
  agg_cache="${TMPDIR:-/tmp}/claude-sl-${session:-anon}.agg"
  if [[ -r $agg_cache ]]; then
    IFS='|' read -r c_size c_in c_out c_cr c_cw c_tools c_kinds c_skills c_mcps \
      c_agents c_turns < "$agg_cache" 2>/dev/null
    if [[ -n $c_size && $c_size == "$agg_size" ]]; then
      t_in=$c_in t_out=$c_out t_cr=$c_cr t_cw=$c_cw tools=$c_tools
      kinds=$c_kinds skills=$c_skills mcps=$c_mcps agents=$c_agents turns=$c_turns
      agg_size=""   # marks "served from cache"; skips the rescan below
    fi
  fi
fi
if [[ -r $transcript_path && -n $agg_size ]]; then
  { IFS= read -r t_in
    IFS= read -r t_out
    IFS= read -r t_cr
    IFS= read -r t_cw
    IFS= read -r tools
    IFS= read -r kinds
    IFS= read -r skills
    IFS= read -r mcps
    IFS= read -r agents
    IFS= read -r turns
  } <<< "$(jq -n '
      reduce inputs as $l (
        {in:0, out:0, cr:0, cw:0, tools:0, names:{}, skills:{}, mcp:{}, agents:0, turns:0};
        ($l.message.usage // {}) as $u
        | .in  += ($u.input_tokens // 0)
        | .out += ($u.output_tokens // 0)
        | .cr  += ($u.cache_read_input_tokens // 0)
        | .cw  += ($u.cache_creation_input_tokens // 0)
        # A user record with toolUseResult is a tool result, not a real prompt.
        | .turns += (if $l.type == "user" and ($l.toolUseResult | not) then 1 else 0 end)
        | reduce ($l.message.content[]? | select(.type == "tool_use")) as $t (.;
            .tools += 1
            | .names[$t.name] = 1
            | if $t.name == "Skill" then .skills[$t.input.skill // "?"] = 1 else . end
            | if $t.name == "Task"  then .agents += 1 else . end
            | if ($t.name | startswith("mcp__"))
                then .mcp[($t.name | split("__")[1] // "?")] = 1 else . end)
      )
      | .in, .out, .cr, .cw, .tools, (.names | length),
        (.skills | length), (.mcp | length), .agents, .turns
    ' "$transcript_path" 2>/dev/null)"
  # jq failure (corrupt line, unreadable) leaves these blank; floor to 0.
  : "${t_in:=0}" "${t_out:=0}" "${t_cr:=0}" "${t_cw:=0}" "${tools:=0}"
  : "${kinds:=0}" "${skills:=0}" "${mcps:=0}" "${agents:=0}" "${turns:=0}"

  # Persist for the next repaint. Written to a temp file and moved into place:
  # statusline invocations can overlap, and mv within one filesystem is atomic,
  # so a concurrent reader sees either the old record or the new one, never a
  # half-written line.
  if [[ -n $agg_cache ]]; then
    if printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$agg_size" "$t_in" "$t_out" "$t_cr" "$t_cw" "$tools" \
        "$kinds" "$skills" "$mcps" "$agents" "$turns" > "$agg_cache.$$" 2>/dev/null
    then mv -f "$agg_cache.$$" "$agg_cache" 2>/dev/null || rm -f "$agg_cache.$$" 2>/dev/null
    else rm -f "$agg_cache.$$" 2>/dev/null
    fi
  fi
fi

# The live payload is authoritative for the current turn's cache activity;
# fall back to the transcript totals when it reports none.
((cache_read == 0 && t_cr > 0))  && cache_read=$t_cr
((cache_write == 0 && t_cw > 0)) && cache_write=$t_cw

# ==================== LINES 2-3: SESSION INSTRUMENTATION ====================
ctx_f="" tok_f="" cache_f="" tool_f="" skill_f="" mcp_f="" agent_f=""
turn_f="" cost_f="" dur_f="" diff_f="" flag_f="" rl5_f="" rl7_f=""

# Context: percentage is only meaningful once reported, and the window size is
# worth naming since it varies by model (1M vs 200k).
if ((ctx_pct)); then
  ctx_col=$G
  ((ctx_pct >= 65)) && ctx_col=$Y
  ((ctx_pct >= 80)) && ctx_col=$R
  if ((ctx_size)); then
    ctx_f="${ctx_col}${ctx_pct}%${Z} ${D}of $(fmt_tok "$ctx_size")${Z}"
  else
    ctx_f="${ctx_col}${ctx_pct}%${Z} ${D}ctx${Z}"
  fi
fi

# Cumulative billed tokens. Input counts every resend of the conversation, so
# it runs far ahead of output - that is expected, not a bug.
((t_in || t_out)) && tok_f="${G}$(fmt_tok "$t_in")↑${Z} ${G}$(fmt_tok "$t_out")↓${Z}"

# Prompt-cache hit rate: reads as a share of everything that could have been
# read. Only rendered when caching actually reports activity.
if ((cache_read || cache_write)); then
  denom=$((cache_read + cache_write + cur_in))
  ((denom == 0)) && denom=$((cache_read + cache_write))
  if ((denom > 0)); then
    hit=$((cache_read * 100 / denom))
    hit_col=$G
    ((hit < 50)) && hit_col=$Y
    ((hit < 20)) && hit_col=$R
    cache_f="${hit_col}${hit}%${Z} ${D}cached${Z}"
    ((cache_write)) && cache_f+=" ${D}(+$(fmt_tok "$cache_write") w)${Z}"
  fi
fi

# Instrumentation counts. Distinct tool kinds are appended only when they add
# information beyond the raw call count.
if ((tools)); then
  tool_f="${C}${tools}${Z} ${D}tools${Z}"
  ((kinds > 1)) && tool_f+="${D}/${kinds}${Z}"
fi
((skills)) && skill_f="${C}$(plural "$skills" skill)${Z}"
((mcps))   && mcp_f="${C}${mcps}${Z} ${D}mcp${Z}"
((agents)) && agent_f="${C}$(plural "$agents" agent)${Z}"
((turns))  && turn_f="${D}$(plural "$turns" turn)${Z}"

# Budget signal differs by billing mode: a subscription reports rate-limit
# windows and usually a $0 cost, while API billing reports dollars and no
# windows. Render whichever the payload actually carries - both if both, and
# nothing if neither - so the line adapts without being told the mode.
if ((rl5_pct >= 0)); then
  rl_col=$G
  ((rl5_pct >= 60)) && rl_col=$Y
  ((rl5_pct >= 85)) && rl_col=$R
  rl5_f="${rl_col}${rl5_pct}%${Z} ${D}5h${Z}"
  # Countdown to window reset, which is what actually gates further work.
  ((rl5_left > 0)) && rl5_f+="${D} ↻$(fmt_dur "$rl5_left")${Z}"
fi
if ((rl7_pct >= 0)); then
  wk_col=$G
  ((rl7_pct >= 60)) && wk_col=$Y
  ((rl7_pct >= 85)) && wk_col=$R
  rl7_f="${wk_col}${rl7_pct}%${Z} ${D}7d${Z}"
fi
((cost_cents)) && cost_f="${G}\$$(printf '%.2f' "$cost_usd")${Z}"

# Duration, with the share actually spent waiting on the model when meaningful.
# The denominator is counted work time, not wall clock - idle time while the
# user reads or types is excluded - so this reads high in a thinking-heavy
# session and only drops when slow local work (builds, test suites) dominates.
# Labelled "wait" rather than "api": it measures response latency, not billing.
if ((dur_s >= 60)); then
  dur_f="${D}$(fmt_dur "$dur_s")${Z}"
  ((api_dur_s > 0 && dur_s > 0)) && dur_f+="${D} ($((api_dur_s * 100 / dur_s))% wait)${Z}"
fi

((added || removed)) && diff_f="${G}+${added}${Z}/${R}-${removed}${Z}"

# Mode flags: only surfaced when they deviate from the quiet default, so this
# stays empty in a normal session.
flags=""
((fast_mode))     && flags+="${Y}fast${Z} "
((thinking == 0)) && flags+="${D}think:off${Z} "
((over_200k))     && flags+="${Y}200k+${Z} "
[[ -n $agent_name ]] && flags+="${P}${agent_name}${Z} "
flag_f=${flags% }

# Two instrumentation groups, each bracketed only when it has content:
#   session - how large the conversation grew and how much work it took
#   budget  - what that work consumed
# Grouped by what each field measures rather than packed to fill each row, so a
# field keeps its position from one repaint to the next and the eye can learn
# where to look. Packing greedily would be tighter but would make fields jump.
session_line="" budget_line=""
session_body=$(join_sep "$ctx_f" "$tok_f" "$cache_f" "$tool_f" "$skill_f" \
                        "$mcp_f" "$agent_f" "$turn_f")
budget_body=$(join_sep "$rl5_f" "$rl7_f" "$cost_f" "$dur_f" "$diff_f" "$flag_f")
[[ -n $session_body ]] && session_line="[${session_body}]"
[[ -n $budget_body ]]  && budget_line="[${budget_body}]"

# ==================== RENDER ====================
# Collect only the lines that exist, then join on newline: printing a fixed
# three-line format would emit blank rows whenever a group has nothing to say,
# which is the normal state at the start of a session.
out=("${head_seg}${path_seg}${git_seg}")
[[ -n $session_line ]] && out+=("$session_line")
[[ -n $budget_line ]]  && out+=("$budget_line")

nl=$'\n'
printf '%s' "$(IFS=$nl; printf '%s' "${out[*]}")"
