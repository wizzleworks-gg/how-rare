#!/usr/bin/env bash
# Build the CurseForge upload zip from the addon folder. The version comes
# from the TOC — bump it there first. Update HowRare/Libs/ (the embedded
# AchievementRarity library) before zipping; see README "Updating the embedded library".
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(grep -m1 '^## Version:' HowRare/HowRare.toc | awk '{print $3}')
out="HowRare-${version}.zip"
rm -f "$out"

# Ship the license inside the addon folder. The repo-root LICENSE is the source
# of truth; this is a transient copy, cleaned up on exit so it's never committed.
cp LICENSE HowRare/LICENSE.txt
trap 'rm -f HowRare/LICENSE.txt' EXIT

zip -qr "$out" HowRare -x '*.DS_Store'
echo "$out"
