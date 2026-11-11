---
name: learn
description: Use when the user runs /learn or asks to turn the current session's lessons into skills, commands, hooks, tools, or AGENTS.md entries. Scans the session transcript, proposes numbered suggestions with evidence, and builds only the ones the user picks.
---

# learn

## Steps

1. **Locate the transcript.** Take the newest `*.jsonl` in the session directory for the current working directory. Claude Code: `~/.claude/projects/<cwd with "/" replaced by "-">/`. If no transcript exists, stop and report that. Do not guess another session.

2. **Collect targets for duplicate checks.** Existing files: repo `AGENTS.md` (and `CLAUDE.md` if present) in the cwd, `~/.agents/AGENTS.md`, `~/.agents/skills/*/SKILL.md`, and repo `.agents/skills/*/SKILL.md`. Missing directories are skipped only when they do not exist in the plan; if a listed path is expected and absent, stop and report it.

3. **Spawn one scanner subagent.** Fresh agent, general-purpose, no model override (uses the main session model). Brief it with:
   - the transcript path and the list of existing target files to grep for duplicates
   - filter to: user messages, explicit user corrections, tool errors and their fixes, commands repeated more than once, workarounds that eventually succeeded, stated preferences
   - rank: explicit corrections first, then repeated manual steps, then workarounds, then preferences
   - cap at 8 suggestions; an empty list is valid
   - drop anything already covered by an existing target
   - per suggestion: number, type (`skill` | `command` | `hook` | `tool` | `agents-md`), scope (`global` | `repo`), title, one-sentence reason, evidence (short quote and turn), proposed content (exact AGENTS.md lines, or skill `description` plus first steps), target path
   - do not write any files, run builds, tests, or devices
   Output as a numbered markdown list.

4. **Show the list verbatim** and ask which numbers to build: a list, `all`, or `none`. Wait for the answer. If `none`, stop.

5. **Build selected suggestions, one at a time, in order.** For each, spawn one builder subagent (fresh, general-purpose, no model override). Brief it with only that one suggestion and these rules:
   - skill: create `<target>/<name>/SKILL.md` with `name` and `description` frontmatter. For global scope, use `~/.agents/skills/<name>/` and symlink `~/.claude/skills/<name>`.
   - command, hook, tool: follow the existing conventions in the target repo; create only what the suggestion names.
   - agents-md: append under the matching existing section; do not duplicate a line already present.
   - if the target path already exists with different content, stop and report the conflict. Do not overwrite.
   - do not run tests, builds, linters, or devices. Do not commit or push.
   - report: created/edited path, or the error that stopped it.
   Wait for each builder to finish before starting the next.

6. **Final report:** one line per suggestion with `created`, `edited`, `skipped`, or `failed` and the path. No recap.

## Rules

- Never invent evidence. A suggestion without a quoted or cited source is dropped.
- Never write secrets or tokens that appear in the transcript into any target file.
- A failed builder stops the chain only for its own item; report the failure and continue with the next selected item.
