#!/usr/bin/env bash
# publish-data.sh — one-command rarity-data publish: prod snapshot → library repo →
# embedded copy. Automates the manual flow in README "Updating the embedded library":
#
#   1. SSH-tunnel to prod Postgres (releases ship PROD numbers, never dev)
#   2. gratz scripts/export-rarity-library.py → regenerates the sibling
#      achievement-rarity repo's data file
#   3. stamp that repo's TOC ## Version: with the snapshot date, commit + push it
#   4. re-copy the versioned lib folder into HowRare/Libs/ and commit here
#      (NOT pushed — tagging the release is the deliberate push, see README)
#
# Idempotent: an unchanged export commits nothing. The export must carry all three
# halves (counts + ranks + all three standing scopes) — a partial export aborts the
# publish before anything is committed.
#
# Needs: sibling ../gratz (with .venv) and ../achievement-rarity checkouts, and SSH
# access to the prod box.
set -euo pipefail
cd "$(dirname "$0")/.."
SIBLINGS="$(dirname "$PWD")"
GRATZ="$SIBLINGS/gratz"
LIB="$SIBLINGS/achievement-rarity"
PROD="root@204.168.168.180"
# Deliberately NOT 15432 (the manual-flow port a long-lived pgAdmin tunnel tends to
# hold) — the script owns its own port so the two never collide.
PORT=15433

[ -x "$GRATZ/.venv/bin/python" ] || { echo "error: $GRATZ/.venv/bin/python not found" >&2; exit 1; }
[ -d "$LIB/.git" ] || { echo "error: $LIB is not a git checkout" >&2; exit 1; }
# The script commits whatever the export wrote — a dirty library repo would fold
# unrelated edits into the data commit. Same for the embed path here.
[ -z "$(git -C "$LIB" status --porcelain)" ] \
  || { echo "error: $LIB has uncommitted changes — commit or stash first" >&2; exit 1; }
# The prod box publishes the library repo nightly (gratz scripts/cron-rarity-publish.sh),
# so this checkout may be behind — sync first or the push below fails.
git -C "$LIB" pull --ff-only
[ -z "$(git status --porcelain -- HowRare/Libs)" ] \
  || { echo "error: HowRare/Libs has uncommitted changes — commit or stash first" >&2; exit 1; }

# Tunnel via a control socket so teardown is deterministic (a bare `ssh -f -N`
# would outlive the script). ExitOnForwardFailure is essential: without it a failed
# bind (port already taken) backgrounds ssh anyway and the export would silently
# ride whatever listener holds the port.
SOCK="$(mktemp -d)/tunnel.sock"
ssh -f -N -M -S "$SOCK" -o ExitOnForwardFailure=yes -L "${PORT}:localhost:5432" "$PROD"
trap 'ssh -S "$SOCK" -O exit "$PROD" 2>/dev/null || true' EXIT

out="$("$GRATZ/.venv/bin/python" "$GRATZ/scripts/export-rarity-library.py" \
  --database-url "postgresql://gratz:gratz@localhost:${PORT}/gratz")"
echo "$out"

# A release must carry the full data set: any export warning means a half-built
# snapshot (counts without ranks/standing) — refuse to publish it.
if grep -q '^warning:' <<<"$out"; then
  echo "error: export warned — a release needs counts + ranks + standing" >&2
  exit 1
fi
case "$out" in
  *"standing scopes: ['eu', 'global', 'us']"*) ;;
  *) echo "error: export missing the three standing scopes" >&2; exit 1 ;;
esac
asof="$(sed -n 's/.*as of \([0-9-]*\),.*/\1/p' <<<"$out")"
[ -n "$asof" ] || { echo "error: could not parse snapshot date from export output" >&2; exit 1; }

# Generated Lua must parse — a syntax-broken data file would brick every consumer.
if command -v luac >/dev/null 2>&1; then
  luac -p "$LIB/AchievementRarity-1.0/AchievementRarity-Data-1.0.lua"
fi

# Library repo: TOC version = the snapshot date (the standalone listing's version;
# date-based, matching the snapshot-derived LibStub minor), then commit + push.
perl -pi -e "s/^## Version:.*/## Version: ${asof//-/.}/" "$LIB/AchievementRarity.toc"
if [ -n "$(git -C "$LIB" status --porcelain)" ]; then
  git -C "$LIB" add -A
  git -C "$LIB" commit -m "data: prod snapshot ${asof}"
else
  echo "library already at ${asof} — nothing to commit"
fi
git -C "$LIB" push

# Embed: copy the versioned lib folder (data + read API; LibStub is static and
# stays put) and normalise modes.
cp -R "$LIB/AchievementRarity-1.0" HowRare/Libs/
chmod 644 HowRare/Libs/AchievementRarity-1.0/*.lua
if [ -n "$(git status --porcelain -- HowRare/Libs)" ]; then
  git add HowRare/Libs/AchievementRarity-1.0
  git commit -m "data: embed snapshot ${asof}"
else
  echo "embed already at ${asof} — nothing to commit"
fi

echo "published: snapshot ${asof} (library pushed; embed committed — tag to release)"
