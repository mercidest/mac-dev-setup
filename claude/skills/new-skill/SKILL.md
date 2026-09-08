---
description: Scaffold a new Claude Code skill (SKILL.md) from my description of what it should do. Use when asked to create, make, or add a new skill.
argument-hint: "What should the skill do?"
---

Create a new skill based on: $ARGUMENTS

## Instructions

1. If the idea is vague, ask me 1-2 quick questions: what should trigger it, and what's the desired output/behavior?
2. Decide scope:
   - Useful in **all my projects** → `~/.claude/skills/<name>/SKILL.md`
   - Specific to **this project** → `.claude/skills/<name>/SKILL.md`
3. Pick a short kebab-case directory name (it becomes the `/slash-command`).
4. Write the SKILL.md following these rules:
   - `description`: one line saying what it does AND when to use it, with words I'd naturally say — this is how Claude decides to auto-load it.
   - Add `disable-model-invocation: true` if it has side effects (commits, deploys, sends anything) so only I can trigger it.
   - Use `` !`command` `` lines to inject live data (git status, file listings) instead of telling Claude to run those commands.
   - Keep the instruction body short and imperative; numbered steps.
5. Show me the file you created and one example of how to invoke it.
