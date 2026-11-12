# agent: small wrapper around git + ./install.sh for the agents repo.
# Linked to ~/.config/zsh/agent.zsh by the installer; sourced from zshrc when present.
# No git operations run on shell startup; `agent push` never stages or commits.

# Repo root: this file's real location (it is reached through a symlink).
typeset -g _AGENT_REPO=${${(%):-%x}:A:h}

# Local session history of Claude Code and omp (cleared by `agent clear history`).
# Kept: credentials, settings, skills, plugins, memory (~/.claude/projects/*/memory), plans.
_agent_history_paths() {
  setopt localoptions extendedglob
  local c=${CLAUDE_CONFIG_DIR:-$HOME/.claude} o=${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}
  reply=(
    $c/history.jsonl(N) $c/{file-history,paste-cache,shell-snapshots,session-env}(N/)
    $c/projects/*/^memory(N)
    $o/history.db*(N) $o/{sessions,blobs}(N/)
  )
}

agent() {
  local cmd=${1:-help} repo=$_AGENT_REPO
  (( $# )) && shift
  [[ -x $repo/install.sh ]] || { print -u2 "agent: repo not found at $repo"; return 1; }
  case $cmd in
    sync)   "$repo/install.sh" sync "$@" ;;
    diff)   git -C "$repo" diff "$@" ;;
    update)
      # pull, show what came in, then sync only after a yes
      local before=$(git -C "$repo" rev-parse HEAD)
      git -C "$repo" pull --ff-only || return
      if [[ $(git -C "$repo" rev-parse HEAD) == $before ]]; then
        print "agent: repo up to date"
      else
        git -C "$repo" log --oneline --stat "$before..HEAD"
      fi
      read -q "?Sync links and skills? [y/N] " || { print; return 1; }
      print
      "$repo/install.sh" sync "$@"
      ;;
    status)
      git -C "$repo" status -sb
      "$repo/install.sh" status "$@"
      ;;
    edit)
      # pinned skills and the links list live here; linked config is edited in place
      ${EDITOR:-vi} "$repo/${1:-skills.pins}"
      ;;
    clear)
      [[ $1 == history ]] || { print -u2 "usage: agent clear history [-y]"; return 2; }
      _agent_history_paths
      (( $#reply )) || { print "agent: no agent history to clear"; return 0; }
      local -a proj=(${(M)reply:#*/projects/*})
      du -sh -- ${reply:#*/projects/*} | sed "s|$HOME|~|"
      (( $#proj )) && print "$(du -shc -- $proj | tail -1 | cut -f1)\t$#proj transcripts in ~/.claude/projects (memory kept)"
      print "total: $(du -shc -- $reply | tail -1 | cut -f1) in $#reply paths"
      if [[ $2 != -y ]]; then
        read -q "?Delete these? [y/N] " || { print; return 1; }
        print
      fi
      command rm -rf -- $reply && print "agent: history cleared"
      ;;
    push)   git -C "$repo" push "$@" ;;
    repo)   cd "$repo" ;;
    help|-h|--help)
      cat <<'EOF'
usage: agent <command>
  sync [links|skills] [-y]  link config into $HOME, install pinned skills
  status       git status of the repo + links and skills
  diff         uncommitted changes (linked config edited by agents shows up here)
  update       pull the repo, show what changed, sync after a yes
  edit [FILE]  edit a repo file (default: skills.pins)
  clear history [-y]  delete Claude Code and omp prompt history and sessions
               (keeps credentials, settings, skills, memory); asks first
  push         push already-committed changes (never stages or commits)
  repo         cd into the agents repo
EOF
      ;;
    *) print -u2 "agent: unknown command: $cmd (agent help)"; return 2 ;;
  esac
}
