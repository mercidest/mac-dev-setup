---
description: Push the current branch and open a GitHub pull request with a well-written description. Use when asked to create or open a PR.
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(gh pr:*)
---

## Branch and status

!`git branch --show-current && git status --short`

## Commits not on the default branch

!`git log --oneline origin/HEAD..HEAD 2>/dev/null || git log --oneline -10`

## Instructions

1. If I'm on the default branch (main/master), stop and tell me — don't create a PR from it.
2. If there are uncommitted changes, ask whether to commit them first (use the /commit skill's conventions).
3. Review the full diff against the default branch to understand the change.
4. Push the branch (`git push -u origin HEAD`).
5. Create the PR with `gh pr create`:
   - **Title**: concise, imperative, matches the repo's commit style.
   - **Body**: a short "Summary" section (what and why, 2-4 bullets) and a "Test plan" section (how it was verified).
6. Print the PR URL.
