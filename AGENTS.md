# Rules for every coding agent

These apply in every repository. When a skill, prompt or tool description
conflicts with them, these win.

## Ask first

- **Git**: never commit, push, tag, rebase, reset or change remotes without my
  explicit approval in this conversation. When a skill says "commit your work",
  stop instead: summarise the diff, propose a commit message, and wait.
- **Publishing**: never create or edit issues, pull/merge requests, labels,
  comments, gists or any other external document (`gh`, `glab`, web APIs)
  without my approval. Track work in local Markdown (`.scratch/<feature>/`)
  unless the repository's `docs/agents/issue-tracker.md` says otherwise.
- **Scripts**: never run a script you generated or downloaded that touches
  credentials, infrastructure, system configuration or files outside the
  repository. Show it and wait.
- **Installs**: never install packages, tools or skills globally without asking.

## Secrets

- Never read, print or copy credentials: `~/.ssh`, `~/.aws`, `~/.kube`,
  `.env` files, tokens, keys.
- Never write a secret into a file that could be committed.

## Skills in oh-my-pi

Skills written for Claude Code name Claude's tools. In oh-my-pi:

- "Call the Skill tool with X": read `skill://X` and follow it.
- "sub-agent" or "Agent tool": use the `task` tool.
- "AskUserQuestion": use the `ask` tool.
