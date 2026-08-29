#!/usr/bin/env bash
# Collects PR + workflow-check status for every dynamo repo in the Harsh-1Byte
# account. Forked repos are read from their upstream (where the PRs live);
# standalone repos are read directly. Writes data.json next to this script.
set -euo pipefail
OUT="$(cd "$(dirname "$0")" && pwd)/data.json"
USER=Harsh-1Byte

repos=$(gh repo list "$USER" --limit 300 --json name --jq '.[].name' | grep '^dynamo-' | grep -vx 'dynamo-status' | sort)

echo '{"generated":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","repos":[' > "$OUT"
first=1
for f in $repos; do
  parent=$(gh repo view "$USER/$f" --json parent \
            --jq 'if .parent then .parent.owner.login+"/"+.parent.name else "" end' 2>/dev/null || true)
  target="$parent"
  [ -z "$target" ] && target="$USER/$f"

  all=$(gh pr list --repo "$target" --state all --limit 30 \
        --json number,title,state,url,updatedAt,createdAt,headRefName,isDraft,author,statusCheckRollup \
        2>/dev/null || echo '[]')
  mine=$(echo "$all" | jq --arg u "$USER" '[.[] | select(.author.login==$u)]')
  foreign=$(echo "$all" | jq --arg u "$USER" '[.[] | select(.author.login!=$u) | {n:.number,state:.state,author:.author.login}]')

  [ "$first" = 1 ] || echo ',' >> "$OUT"
  first=0
  jq -n --arg fork "$f" --arg repo "$target" --argjson prs "$mine" --argjson foreign "$foreign" \
     '{fork:$fork,repo:$repo,url:("https://github.com/"+$repo),prs:$prs,foreign:$foreign}' >> "$OUT"
  echo "  $target — $(echo "$mine" | jq length) yours, $(echo "$foreign" | jq length) other" >&2
done
echo ']}' >> "$OUT"
echo "wrote $OUT" >&2
