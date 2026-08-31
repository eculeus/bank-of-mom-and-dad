#!/bin/bash
# One-time history rewrite: purge the old family-photo app-icon blobs from git
# history while keeping the current gradient "$" icon and all commit history.
# Rewrites every commit SHA and force-pushes — run this yourself and review.
#
#   bash scripts/purge-icon-photo.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

FR="$HOME/Library/Python/3.11/bin/git-filter-repo"
[ -x "$FR" ] || FR="$(command -v git-filter-repo)"
[ -n "$FR" ] || { echo "git-filter-repo not found (pip install --user git-filter-repo)"; exit 1; }

ORIGIN="$(git remote get-url origin)"
echo "origin: $ORIGIN"

# 1. Full backup (restore with: git clone /tmp/bomad-repo-backup.bundle)
git bundle create /tmp/bomad-repo-backup.bundle --all
echo "backup: /tmp/bomad-repo-backup.bundle"

# 2. Icon paths that ever held the photo
PATHS=$(git ls-files 'web/favicon.png' 'web/icons/*.png' \
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png')

# 3. Current ($) blobs to KEEP vs every historical blob at those paths
git ls-tree -r HEAD -- $PATHS | awk '{print $3}' | sort -u > /tmp/bomad-keep.txt
git log --all --format= --raw --no-abbrev -- $PATHS \
  | awk '{print $3"\n"$4}' | grep -E '^[0-9a-f]{40}$' | grep -v '^0*$' \
  | sort -u > /tmp/bomad-all.txt
comm -23 /tmp/bomad-all.txt /tmp/bomad-keep.txt > /tmp/bomad-strip.txt
echo "keeping $(wc -l < /tmp/bomad-keep.txt) current blob(s); stripping $(wc -l < /tmp/bomad-strip.txt) old photo blob(s)"
[ -s /tmp/bomad-strip.txt ] || { echo "nothing to strip — aborting"; exit 1; }

# 4. Rewrite history (drops the origin remote as a safety measure)
"$FR" --strip-blobs-with-ids /tmp/bomad-strip.txt --force

# 5. Re-add origin and force-push the rewritten history
git remote add origin "$ORIGIN"
git push --force --all origin
git push --force --tags origin || true

echo
echo "DONE. Photo purged from history, current \$ icon intact, force-pushed."
echo "Note: GitHub may keep unreachable commits accessible by direct SHA for a"
echo "while (and forks/caches persist). For a non-credential photo that's usually"
echo "fine; to purge cached views entirely, contact GitHub Support."
