#!/usr/bin/env bash
# agents installer: link agent config from this repo into $HOME and install
# pinned skills. Daily use goes through the `agent` zsh function (agent.zsh).
# Bash 3.2 compatible (macOS /bin/bash). Safe to rerun; never edits skills.pins.
set -u

usage() {
  cat <<'EOF'
usage: ./install.sh [command]

  sync [links|skills] [-y]   (default) link config into $HOME, install pinned
                             skills (both by default); -y: replace existing files
                             without asking (they are still backed up)
  status                     links and skills: ok / missing / replaced /
                             unpinned / drift / local
  help                       this help

Config links: ./links. Third-party skills: ./skills.pins. Own skills: ./skills/<name>/.
EOF
}

REPO="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/agents/backup/$STAMP"
# Where the skills CLI keeps its lock (src/skill-lock.ts in vercel-labs/skills).
if [ -n "${XDG_STATE_HOME:-}" ]; then LOCK="$XDG_STATE_HOME/skills/.skill-lock.json"
else LOCK="$HOME/.agents/.skill-lock.json"; fi
# pi installs into ~/.agents/skills, which oh-my-pi reads; claude-code gets symlinks.
TARGET_AGENTS="-a claude-code -a pi"
ASSUME_YES=false
FAILED=""

say() { printf '%s\n' "$*"; }
fail() { FAILED="$FAILED $*;"; printf 'error: %s\n' "$*" >&2; }
has() { command -v "$1" >/dev/null 2>&1; }
valid_sha() { case "$1" in *[!0-9a-f]* | "") return 1 ;; esac; [ ${#1} -eq 40 ]; }
# Loops read their rows from stdin, so questions go to the terminal.
confirm() {
  [ "$ASSUME_YES" = true ] && return 0
  { : </dev/tty; } 2>/dev/null || return 1
  local a
  printf '%s [y/N] ' "$1" >/dev/tty
  read -r a </dev/tty
  case "$a" in y | Y | yes) return 0 ;; *) return 1 ;; esac
}
rows() { grep -v '^[[:space:]]*\(#\|$\)' "$1"; }
# A pulled commit must not reach outside the repo or $HOME, or smuggle in globs.
safe_rel() {
  case "$1" in "" | /* | ..* | */..* | *[!A-Za-z0-9._/-]*) return 1 ;; esac
}
valid_source() { printf '%s' "$1" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; }
valid_names() { printf '%s' "$1" | grep -Eq '^[a-z0-9][a-z0-9-]*(,[a-z0-9][a-z0-9-]*)*$'; }

# --- links -----------------------------------------------------------------------

own_skills() {
  local d
  for d in "$REPO"/skills/*/; do
    [ -f "$d/SKILL.md" ] && basename "$d"
  done
}

# "repo-path home-path" per line: ./links plus two links per own skill.
links() {
  rows "$REPO/links"
  local s
  for s in $(own_skills); do
    echo "skills/$s .agents/skills/$s"
    echo "skills/$s .claude/skills/$s"
  done
}

# ok | missing | replaced (a real file or dir) | other-link
link_state() {
  local src="$REPO/$1" dst="$HOME/$2"
  if [ -L "$dst" ]; then
    [ "$(readlink "$dst")" = "$src" ] && echo ok || echo other-link
  elif [ -e "$dst" ]; then
    echo replaced
  else
    echo missing
  fi
}

sync_links() {
  local src dst st
  say "==> links"
  while read -r src dst; do
    [ -n "$src" ] || continue
    safe_rel "$src" && safe_rel "$dst" || { fail "links: unsafe path in '$src $dst'"; continue; }
    [ -e "$REPO/$src" ] || { fail "links: $src is not in the repo"; continue; }
    st="$(link_state "$src" "$dst")"
    case "$st" in
      ok) continue ;;
      missing) ;;
      *)
        say "~/$dst already exists ($st)"
        [ -f "$HOME/$dst" ] && [ ! -L "$HOME/$dst" ] && diff -u "$HOME/$dst" "$REPO/$src" | sed 's/^/  /'
        confirm "Back up ~/$dst and link it to the repo?" || { say "  kept ~/$dst"; continue; }
        mkdir -p "$(dirname "$BACKUP_DIR/$dst")" && mv "$HOME/$dst" "$BACKUP_DIR/$dst" ||
          { fail "backup of ~/$dst"; continue; }
        say "  backup: $BACKUP_DIR/$dst"
        ;;
    esac
    mkdir -p "$(dirname "$HOME/$dst")" && ln -s "$REPO/$src" "$HOME/$dst" &&
      say "linked ~/$dst -> $src" || fail "link ~/$dst"
  done <<EOF
$(links)
EOF
}

# --- skills ----------------------------------------------------------------------

# The skills CLI at the version pinned in skills.pins, through mise (needs node).
skills_cli() {
  local v
  v="$(rows "$REPO/skills.pins" | awk '$1 == "cli" && $2 == "skills" { print $3 }')"
  printf '%s' "$v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
    { fail "skills.pins: need 'cli skills <x.y.z>' (exact version)"; return 1; }
  has mise || { fail "mise is needed to run the skills CLI"; return 1; }
  DISABLE_TELEMETRY=1 mise exec "npm:skills@$v" -- skills "$@"
}

# Commit the lock records for an installed skill, empty when not installed.
locked_ref() {
  [ -f "$LOCK" ] && [ -e "$HOME/.agents/skills/$1" ] || return 0
  jq -r --arg n "$1" '.skills[$n].ref // ""' "$LOCK" 2>/dev/null
}

sync_skills() {
  local kind src sha names n todo
  say "==> skills"
  has jq || { fail "jq is needed to read the skills lock"; return; }
  while read -r kind src sha names; do
    [ "$kind" = skills ] || continue
    valid_source "$src" || { fail "skills.pins: source must be owner/repo: $src"; continue; }
    valid_sha "$sha" || { fail "skills.pins: $src: commit must be a full 40-character id"; continue; }
    valid_names "$names" || { fail "skills.pins: $src: names must be a-z0-9- separated by commas"; continue; }
    todo=""
    for n in $(echo "$names" | tr ',' ' '); do
      [ "$(locked_ref "$n")" = "$sha" ] || todo="$todo -s $n"
    done
    if [ -z "$todo" ]; then
      say "$src @ $(echo "$sha" | cut -c1-7): up to date"
      continue
    fi
    say "$src @ $(echo "$sha" | cut -c1-7): installing$(echo "$todo" | sed 's/ -s / /g')"
    # $TARGET_AGENTS and $todo are word lists on purpose
    skills_cli add "$src#$sha" -g -y $TARGET_AGENTS $todo || fail "install from $src"
  done <<EOF
$(rows "$REPO/skills.pins")
EOF
}

# --- status ----------------------------------------------------------------------

status() {
  local src dst kind sha names n ref st pinned="" own
  say "LINKS"
  while read -r src dst; do
    [ -n "$src" ] && printf '  %-44s %-10s %s\n' "~/$dst" "$(link_state "$src" "$dst")" "$src"
  done <<EOF
$(links)
EOF

  say "SKILLS"
  has jq || { say "  (jq not found: skill state unknown)"; return; }
  while read -r kind src sha names; do
    [ "$kind" = skills ] || continue
    for n in $(echo "$names" | tr ',' ' '); do
      pinned="$pinned $n"
      ref="$(locked_ref "$n")"
      if [ -z "$ref" ]; then st=missing
      elif [ "$ref" = "$sha" ]; then st=ok
      else st="drift ($(echo "$ref" | cut -c1-7))"; fi
      printf '  %-30s %-22s %s  %s\n' "$n" "$src" "$(echo "$sha" | cut -c1-7)" "$st"
    done
  done <<EOF
$(rows "$REPO/skills.pins")
EOF
  own="$(own_skills)"
  for n in $own; do
    printf '  %-30s %-22s %s  %s\n' "$n" "agents repo" "-------" local
  done
  [ -f "$LOCK" ] || return 0
  # installed by the CLI but in neither skills.pins nor skills/
  for n in $(jq -r '.skills | keys[]' "$LOCK" 2>/dev/null); do
    case " $pinned $own " in *" $n "*) continue ;; esac
    printf '  %-30s %-22s %s  %s\n' "$n" "$(jq -r --arg n "$n" '.skills[$n].source' "$LOCK")" "-------" unpinned
  done
}

# --- main ------------------------------------------------------------------------

cmd="${1:-sync}"
[ $# -gt 0 ] && shift
what=""
for a in "$@"; do
  case "$a" in
    -y | --yes) ASSUME_YES=true ;;
    links | skills) what="$a" ;;
    *) say "unknown argument: $a (./install.sh help)" >&2; exit 2 ;;
  esac
done

case "$cmd" in
  sync)
    [ "$what" = skills ] || sync_links
    [ "$what" = links ] || sync_skills
    ;;
  status) status ;;
  help | -h | --help) usage ;;
  *) say "unknown command: $cmd (./install.sh help)" >&2; exit 2 ;;
esac

if [ -n "$FAILED" ]; then
  say "failed:$FAILED" >&2
  exit 1
fi
