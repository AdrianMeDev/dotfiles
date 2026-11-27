#!/usr/bin/env bash
# Claude Code statusline: model, context usage in %, tokens against the ~150k agent budget.
# Plain bash on purpose (no jq dependency). Reads the status JSON from stdin, always exits 0.
BUDGET=150000
WARN=90000 # yellow from 60 % of the budget; red from BUDGET

json=$(cat)

# field <key> -> first scalar value of "key": <value>, empty if missing or null
field() {
    local re="\"$1\"[[:space:]]*:[[:space:]]*(\"([^\"]*)\"|[0-9.]+)"
    if [[ $json =~ $re ]]; then
        printf '%s' "${BASH_REMATCH[2]:-${BASH_REMATCH[1]}}"
    fi
}

model=$(field display_name)
pct=$(field used_percentage)
pct=${pct%%.*}
[[ $pct =~ ^[0-9]+$ ]] || pct=''

tokens=''
sum=0
for key in input_tokens cache_creation_input_tokens cache_read_input_tokens; do
    value=$(field "$key")
    if [[ $value =~ ^[0-9]+$ ]]; then
        tokens=1
        sum=$((sum + value))
    fi
done

pct_text='–'
[[ -n $pct ]] && pct_text="${pct}%"
tok_text='–'
color=''
if [[ -n $tokens ]]; then
    tok_text="$((sum / 1000))k"
    if ((sum >= BUDGET)); then
        color=$'\033[31m'
        tok_text="${tok_text}!"
    elif ((sum >= WARN)); then
        color=$'\033[33m'
    fi
fi
reset=''
[[ -n $color ]] && reset=$'\033[0m'

printf '%s · %s · %s%s/%dk%s\n' "${model:-Claude}" "$pct_text" "$color" "$tok_text" "$((BUDGET / 1000))" "$reset"
exit 0
