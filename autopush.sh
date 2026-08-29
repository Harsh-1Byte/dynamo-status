#!/usr/bin/env bash
# Refresh the board from GitHub and push it, so the Pages link stays current.
# Runs under launchd; uses the gh CLI's existing login.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
./collect.sh >/dev/null 2>>refresh.log
python3 build.py >>refresh.log 2>&1
if ! git diff --quiet -- index.html data.json; then
  git add index.html data.json
  git -c user.name="Harsh-1Byte" -c user.email="harsh.wardhn.mail@gmail.com" \
      commit -q -m "status refresh $(date -u +%Y-%m-%dT%H:%MZ)"
  git push -q origin main
  echo "$(date -u +%FT%TZ) pushed" >> refresh.log
else
  echo "$(date -u +%FT%TZ) no change" >> refresh.log
fi
