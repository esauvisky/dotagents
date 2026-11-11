#!/usr/bin/env bash
set -euo pipefail

# Recursion guard: the claude -p call below fires its own Stop hooks.
if [[ -n "${TITLE_HOOK_ACTIVE:-}" ]]; then
  exit 0
fi

input=$(cat)
transcript=$(jq -r '.transcript_path' <<<"$input")
session_id=$(jq -r '.session_id' <<<"$input")

user_prompts='map(select(.type=="user" and (.isMeta|not) and (.message.content|type=="string") and (.message.content|startswith("<")|not)))'

turns=$(jq -s "$user_prompts | length" "$transcript")
if (( turns == 0 || turns % 10 != 0 )); then
  exit 0
fi

last_title=$(jq -s '[.[] | select(.type=="custom-title")] | last' "$transcript")
if [[ "$last_title" != "null" ]] && [[ $(jq -r '.auto // false' <<<"$last_title") != "true" ]]; then
  exit 0
fi

prompts=$(jq -rs "$user_prompts | .[-10:] | map(.message.content[0:300]) | join(\"\n---\n\")" "$transcript")

title=$(TITLE_HOOK_ACTIVE=1 claude -p --model haiku --no-session-persistence "Write a short title (max 6 words, no quotes, no trailing punctuation) for the current topic of this conversation. Output only the title.

Recent user messages:
$prompts")

title=$(sed 's/^["[:space:]]*//;s/["[:space:]]*$//' <<<"$title" | head -n1)
if [[ -z "$title" ]]; then
  echo "auto-title: model returned an empty title" >&2
  exit 1
fi

jq -cn --arg t "$title" --arg s "$session_id" '{type: "custom-title", customTitle: $t, sessionId: $s, auto: true}' >> "$transcript"
