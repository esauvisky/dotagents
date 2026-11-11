#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
prompt=$(jq -r '.prompt' <<<"$input")

if [[ "$prompt" != %* ]]; then
  exit 0
fi

session_id=$(jq -r '.session_id' <<<"$input")
cwd=$(jq -r '.cwd' <<<"$input")
transcript=$(jq -r '.transcript_path' <<<"$input")
rest=$(sed 's/^[[:space:]]*//' <<<"${prompt:1}")

title=$(jq -rs 'map(select(.type=="user" and (.isMeta|not) and (.message.content|type=="string") and (.message.content|startswith("<")|not)))[0].message.content' "$transcript")
if [[ -z "$title" || "$title" == "null" ]]; then
  echo "split-session: no first prompt found in $transcript" >&2
  exit 1
fi
if (( ${#title} > 64 )); then
  title="${title:0:64}..."
fi

if [[ -n "$rest" ]]; then
  name="⎇ $title [$rest]"
else
  name="⎇ $title"
fi

printf -v cmd 'env -u CLAUDE_CODE_CHILD_SESSION claude --resume %q --fork-session --name %q' "$session_id" "$name"
if [[ -n "$rest" ]]; then
  printf -v cmd '%s %q' "$cmd" "$rest"
  reason="Forked session opened with prompt."
else
  reason="Forked session opened in a new terminal."
fi

gnome-terminal --working-directory="$cwd" -- bash -c "$cmd; exec bash"

jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
