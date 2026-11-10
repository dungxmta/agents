# agents

Config and skills for my coding agents (Claude Code, oh-my-pi). Files stay in
this repo; `$HOME` gets symlinks to them, so an edit in either place is an edit
here. Agent state (sessions, history, credentials) never enters the repo.

## Install

```sh
git clone https://github.com/dungxmta/agents.git ~/SYNC/agents
~/SYNC/agents/install.sh        # = bin/agent sync
```

Needs `git`, `jq`, and `mise` with Node.js (for the skills CLI).

## Use

```sh
agent status          # links and skills at a glance
agent sync            # link config + install pinned skills
agent sync links      # only the links (no network)
```

`sync` backs up and asks before replacing an existing file
(`~/.local/state/agents/backup/<time>/`). It installs exactly what
`skills.pins` lists and never edits that file.

## Layout

| Path | What |
|---|---|
| `AGENTS.md` | rules for every agent (→ `~/.claude/CLAUDE.md`, `~/.agents/AGENTS.md`) |
| `claude/` | Claude Code settings (→ `~/.claude/`) |
| `skills/<name>/` | my own skills (→ `~/.agents/skills/`, `~/.claude/skills/`) |
| `links` | every repo file → home path |
| `skills.pins` | third-party skills at exact commits, plus the skills CLI version |

## Adding a skill

Review it upstream, then add its name to the source's row in `skills.pins`
(or a new row with a full commit id) and run `agent sync skills`.
