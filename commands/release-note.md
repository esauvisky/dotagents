---
description: Draft a release announcement from commits and Discord exports, asking which changes to include
argument-hint: [since-tag-or-ref]
allowed-tools: Bash(git log:*), Bash(git show:*), Bash(cat:*), Bash(ls:*), Bash(grep:*), Bash(find:*)
---

# /release-note: draft a release announcement

You are drafting the announcement for repo: (cwd on invocation) with range: $ARGUMENTS (a tag, ref, or "last announced version"; defaults to the previous tag/announced bump if empty).

1. **Gather the candidate changes**
   - `git log --oneline <since>..HEAD` — every commit since the given ref.
   - If the repo's parent ecosystem has Discord exports (`../secrets/exports/` relative to the Pokemod root, or a path named in AGENTS.md), `ls` it and identify the file(s) covering the same period; read the ones relevant to the changes.
   - If $ARGUMENTS is empty: ask the user which ref to announce since — or list the last few tags/versions and offer them as choices in one question.

2. **Ask which changes to include** (this is the point of the command)
   - Present the commits grouped by area (features / fixes / module changes), each with a one-line description in your words.
   - Ask one batched question: which groups/commits to announce, which to skip, and which to reword. Do not proceed to drafting until answered. If the user answered $ARGUMENTS with an explicit list of commits to include, skip the question.

3. **Draft**
   - Voice: match past announcements from the Discord export if any exist (tone, emoji usage, length, header format). If none, neutral feature-list style: header with the version, bullets per included change, brief closing.
   - No file changes in this step. Output the draft in a fenced block.
   - Never invent a change; every bullet must trace to a specific commit or export entry (name the commit hash in the draft only if the repo's past announcements do so).

4. **Deliver**
   - Show the final draft and offer the variants: post-ready text (for Discord), and with the user's approval one clean copy for the repo CHANGELOG.md if one exists. Never post anywhere automatically — delivery is manual by the user or an explicitly requested separate step.

If the user names a specific Discord export file or message list, use it as the primary source and commits only as supporting material.
