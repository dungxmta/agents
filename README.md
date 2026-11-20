# agents

Config and skills for my coding agents (Claude Code, oh-my-pi).

Config files live here and are symlinked into `$HOME`, so edits made by hand or
by an agent show up in `git diff`. Sessions, history and credentials stay in
`$HOME` and never enter the repo.

## Install

```sh
git clone https://github.com/dungxmta/agents.git ~/SYNC/agents
~/SYNC/agents/install.sh
exec zsh
```

Needs `git`, `jq`, and `mise` with Node.js. With
[dotfiles](https://github.com/dungxmta/dotfiles): `./install.sh --with-agents`.

## Use

```sh
agent status        # repo, links and skills
agent sync          # link config, install pinned skills
agent update        # pull, show changes, sync after a yes
agent diff          # uncommitted changes
agent edit          # edit skills.pins
agent push          # push commits (never stages or commits)
```

`sync` installs exactly what `skills.pins` lists and never edits it. It asks
before replacing an existing file and backs it up to
`~/.local/state/agents/backup/`.

## Layout

| Path | Linked to |
|---|---|
| `AGENTS.md` | `~/.claude/CLAUDE.md`, `~/.claude-home/CLAUDE.md`, `~/.agents/AGENTS.md` |
| `claude/` | `~/.claude/`, `~/.claude-home/` |
| `skills/<name>/` | `~/.agents/skills/`, `~/.claude/skills/` |
| `agent.zsh` | `~/.config/zsh/agent.zsh` |

`links` lists every link; `skills.pins` pins third-party skills to exact commits.

`claude/plugins/claude-hud/config.json` is a hard link, not a symlink: claude-hud
won't read its config through a symlink. `hud set` and a `git pull` that changes
the file each replace one side, so the two copies split. `agent status` then
shows `split`, and `agent sync` shows the diff, asks whether to keep the `~`
version (copied into the repo) or the repo's (the `~` one is backed up), and
links them again. The repo and `~` must be on the same disk.

## Claude profiles

`claude` uses `~/.claude` (work account). `claude-home` (in `agent.zsh`) runs it
with `CLAUDE_CONFIG_DIR=~/.claude-home` (personal account): its own login,
history, sessions, memory and plugins. `CLAUDE.md`, `settings.json` and the HUD
config are linked into both; `~/.claude-home/skills` links to `~/.claude/skills`
(made by `claude-home` on first run).

First run: `agent sync`, then `claude-home` and `/login` with the personal
account; install the HUD plugin there (`/plugin install claude-hud@claude-hud`,
then `/hud`). Clear its history with `CLAUDE_CONFIG_DIR=~/.claude-home agent clear history`.

## Adding a skill

Read the skill upstream first: skills are instructions an agent follows with
your permissions. Then add its name to the source's row in `skills.pins` (or a
new row with a full commit id) and run `agent sync`.
