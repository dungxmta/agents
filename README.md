# agents

Config and skills for my coding agents (Claude Code, oh-my-pi). Files stay in
this repo; `$HOME` gets symlinks to them, so an edit in either place is an edit
here. Agent state (sessions, history, credentials) never enters the repo.

## Install

```sh
git clone https://github.com/dungxmta/agents.git ~/SYNC/agents
~/SYNC/agents/install.sh        # links config + installs skills, then: exec zsh
```

Needs `git`, `jq`, and `mise` with Node.js (for the skills CLI).

## Use

`agent` is a zsh function (`agent.zsh`, linked to `~/.config/zsh/agent.zsh`
and sourced by zshrc when present), like `dot` for the dotfiles repo.

```sh
agent status          # git status + links and skills at a glance
agent sync            # link config + install pinned skills
agent sync links      # only the links (no network)
agent update          # pull, show changes, sync after a yes
agent diff            # what agents changed in linked config
agent edit            # edit skills.pins
agent push | repo     # push commits | cd into the repo
```

Without zsh: `./install.sh sync|status`.

`sync` backs up and asks before replacing an existing file
(`~/.local/state/agents/backup/<time>/`). It installs exactly what
`skills.pins` lists and never edits that file.

## Layout

| Path | What |
|---|---|
| `AGENTS.md` | rules for every agent (→ `~/.claude/CLAUDE.md`, `~/.agents/AGENTS.md`) |
| `claude/` | Claude Code settings (→ `~/.claude/`) |
| `skills/<name>/` | my own skills (→ `~/.agents/skills/`, `~/.claude/skills/`) |
| `agent.zsh` | the `agent` command |
| `install.sh` | the installer behind it |
| `links` | every repo file → home path |
| `skills.pins` | third-party skills at exact commits, plus the skills CLI version |

## Adding a skill

Review it upstream, then add its name to the source's row in `skills.pins`
(or a new row with a full commit id) and run `agent sync skills`.
