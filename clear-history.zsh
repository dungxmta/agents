#!/usr/bin/env zsh
# Delete the local session history of Claude Code (~/.claude, and ~/.claude-home when that
# profile exists) and omp, asking before each delete.
# Run it through `agent clear history`, which first checks this file against the pushed copy.
# Kept: credentials, settings, skills, plugins, memory (~/.claude/projects/*/memory), plans.
setopt extendedglob nullglob
cs=(${CLAUDE_CONFIG_DIR:-$HOME/.claude}) o=${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}
[[ -d $HOME/.claude-home && $cs[1] != $HOME/.claude-home ]] && cs+=($HOME/.claude-home)
for c in $cs $o; do
  [[ $c == /?* ]] || { print -u2 "clear-history: bad config dir: $c"; exit 1; }
done

quit= n=0
# ask_rm LABEL PATH... — one confirmation, one rm, only for paths inside the agent dirs
ask_rm() {
  local label=$1 p r key; shift
  (( $# )) && [[ -z $quit ]] || return 0
  for p; do
    for r in $cs $o; do [[ $p == $r/?* ]] && break; r=; done
    [[ -n $r && $p != */../* ]] || { print -u2 "clear-history: refusing $p"; exit 1; }
  done
  print -n "delete $label ($(du -shc -- "$@" | tail -1 | cut -f1))? [y/N/q] "
  while read -t 0 -k1 key </dev/tty; do :; done   # drop keys typed before the prompt
  key=; read -k1 key </dev/tty; print
  case $key in
    [yY]) command rm -rf -- "$@" && (( n += $# )) ;;
    [qQ]) quit=1 ;;
  esac
}

for c in $cs; do
  ask_rm "Claude prompt history ${c/#$HOME/~}/history.jsonl" $c/history.jsonl
  for d in file-history paste-cache shell-snapshots session-env; do
    ask_rm "${c/#$HOME/~}/$d" $c/$d(/)
  done
  for p in $c/projects/*(/); do
    t=($p/^memory)
    ask_rm "$#t transcripts in ${p/#$HOME/~}" $t
  done
done
ask_rm "omp prompt history ${o/#$HOME/~}/history.db" $o/history.db*
for d in sessions blobs; do
  ask_rm "omp ${o/#$HOME/~}/$d" $o/$d(/)
done
print "clear-history: deleted $n paths${quit:+ (stopped)}"
