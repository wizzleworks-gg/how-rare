#!/usr/bin/env bash
# Build the CurseForge upload zip from the addon folder. The version comes
# from the TOC — bump it there first. Refresh Data/ from PROD before zipping.
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(grep -m1 '^## Version:' AchievementRarity/AchievementRarity.toc | awk '{print $3}')
out="AchievementRarity-${version}.zip"
rm -f "$out"

# Ship the license inside the addon folder. The repo-root LICENSE is the source
# of truth; this is a transient copy, cleaned up on exit so it's never committed.
cp LICENSE AchievementRarity/LICENSE.txt
trap 'rm -f AchievementRarity/LICENSE.txt' EXIT

zip -qr "$out" AchievementRarity -x '*.DS_Store'
echo "$out"
