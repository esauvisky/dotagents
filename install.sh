#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
agents="$HOME/.agents"
if [[ ! -e "$agents" && ! -L "$agents" ]]; then
  ln -sT "$repo" "$agents"
fi

top=$(git -C "$agents" rev-parse --show-toplevel)
if [[ "$top" != "$(readlink -f "$agents")" ]]; then
  echo "install: $agents must be the dotagents checkout" >&2
  exit 1
fi

link() {
  local src=$1 dst=$2
  if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    return 0
  fi
  ln -sT "$src" "$dst"
}

mkdir -p "$HOME/.claude/skills" "$HOME/.local/bin"

link "$agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"
link "$agents/hooks" "$HOME/.claude/hooks"
link "$agents/commands" "$HOME/.claude/commands"
link "$agents/bin/cfind" "$HOME/.local/bin/cfind"
for d in "$agents/skills"/*/; do
  [[ -f "${d}SKILL.md" ]] || continue
  s=$(basename "$d")
  link "$agents/skills/$s" "$HOME/.claude/skills/$s"
done

settings="$HOME/.claude/settings.json"
[[ -f "$settings" ]] || echo '{}' > "$settings"
tmp=$(mktemp)
jq --arg home "$HOME" '
  def ensure_hook($event; $cmd):
    .hooks[$event] = ((.hooks[$event] // []) |
      if any(.[]; .hooks[]?.command == $cmd) then .
      else . + [{"hooks": [{"type": "command", "command": $cmd}]}]
      end);
  ensure_hook("Stop"; "\($home)/.claude/hooks/stop-verify.sh")
  | ensure_hook("Stop"; "\($home)/.claude/hooks/auto-title.sh")
  | ensure_hook("UserPromptSubmit"; "\($home)/.claude/hooks/split-session.sh")
' "$settings" > "$tmp"
mv "$tmp" "$settings"

for h in .iflow .qwen .augment .openhands .openclaw .qoder .config/goose; do
  if [[ -d "$HOME/$h" ]]; then
    link "$agents/skills" "$HOME/$h/skills"
  fi
done

if [[ -d "$HOME/.codex" ]]; then
  link "$agents/AGENTS.md" "$HOME/.codex/AGENTS.md"
fi
if [[ -d "$HOME/.config/opencode" ]]; then
  link "$agents/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
  link "$agents/commands" "$HOME/.config/opencode/commands"
  link "$agents/skills" "$HOME/.config/opencode/skills"
fi
