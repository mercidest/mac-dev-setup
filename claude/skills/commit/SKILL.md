---
description: Write a clear commit message from the current changes and commit them. Use when committing work or asked for a commit message.
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*)
---

## Current state

!`git status`

## Staged changes

!`git diff --cached --stat`

## Unstaged changes

!`git diff --stat`

## Recent commit style

!`git log --oneline -10`

## Instructions

1. If nothing is staged, stage the modified/untracked files that belong to one logical change (ask before staging if the changes look like they should be split into multiple commits).
2. Read the full diff of what will be committed (`git diff --cached`).
3. Write a commit message that matches the style of the recent commits above (conventional commits if the repo uses them). Subject line ≤ 72 chars, imperative mood; add a short body only if the "why" isn't obvious.
4. Commit. Show the final `git log -1 --stat` as confirmation.

Never push unless I explicitly ask.
