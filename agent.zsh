# agent: small wrapper around git + ./install.sh for the agents repo.
# Linked to ~/.config/zsh/agent.zsh by the installer; sourced from zshrc when present.
# No git operations run on shell startup; `agent push` never stages or commits.

# Repo root: this file's real location (it is reached through a symlink).
typeset -g _AGENT_REPO=${${(%):-%x}:A:h}

# sha256 of $1, as printed by whichever tool this OS has
_agent_sha256() {
  if (( $+commands[sha256sum] )); then print -rn -- "$1" | sha256sum
  else print -rn -- "$1" | shasum -a 256; fi | cut -d' ' -f1
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
      [[ $1 == history && $# == 1 ]] || { print -u2 "usage: agent clear history"; return 2; }
      # Run only the pushed clear-history.zsh: read it once, compare its hash with the
      # upstream copy, then execute exactly the bytes that were checked (zsh -f: no rc files).
      local f=clear-history.zsh code want h
      code=$(cat -- "$repo/$f" && print -n .) || return 1
      want=$(git -C "$repo" show "@{u}:$f" 2>/dev/null && print -n .) ||
        { print -u2 "agent: $f is not on the upstream branch (push it first)"; return 1; }
      h=$(_agent_sha256 "$code")
      if [[ $h != $(_agent_sha256 "$want") ]]; then
        print -u2 "agent: $f differs from the pushed copy (sha256 $h); not running it"
        print -u2 "       review: git -C ${repo/#$HOME/~} diff @{u} -- $f"
        return 1
      fi
      print "agent: $f matches $(git -C "$repo" rev-parse --abbrev-ref @{u}) (sha256 ${h[1,16]})"
      zsh -fc "${code%.}" clear-history
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
  clear history  delete Claude Code and omp prompt history and sessions, asking
               before each delete; runs only if clear-history.zsh matches the pushed copy
  push         push already-committed changes (never stages or commits)
  repo         cd into the agents repo
EOF
      ;;
    *) print -u2 "agent: unknown command: $cmd (agent help)"; return 2 ;;
  esac
}
