#!/usr/bin/env bash
# Collects PR + workflow-check status for every dynamo repo in the Harsh-1Byte
# account. Forked repos are read from their upstream (where the PRs live);
# standalone repos are read directly. Writes data.json next to this script.
set -euo pipefail
OUT="$(cd "$(dirname "$0")" && pwd)/data.json"
TMP="$OUT.tmp"
trap 'rm -f "$TMP"' EXIT
USER=Harsh-1Byte

repos=$(gh repo list "$USER" --limit 300 --json name --jq '.[].name' | grep '^dynamo-' | grep -vx 'dynamo-status' | sort)

echo '{"generated":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","repos":[' > "$TMP"
first=1
for f in $repos; do
  parent=$(gh repo view "$USER/$f" --json parent \
            --jq 'if .parent then .parent.owner.login+"/"+.parent.name else "" end' 2>/dev/null || true)
  target="$parent"
  [ -z "$target" ] && target="$USER/$f"

  all=$(gh pr list --repo "$target" --state all --limit 30 \
        --json number,title,state,url,updatedAt,createdAt,headRefName,isDraft,author,statusCheckRollup \
        2>/dev/null || echo '[]')
  if ! echo "$all" | jq -e . >/dev/null 2>&1; then
    echo "  !! $target — GitHub returned no usable JSON, aborting rather than publishing a partial board" >&2
    exit 1
  fi
  mine=$(echo "$all" | jq --arg u "$USER" '[.[] | select(.author.login==$u)]')
  foreign=$(echo "$all" | jq --arg u "$USER" '[.[] | select(.author.login!=$u) | {n:.number,state:.state,author:.author.login}]')

  [ "$first" = 1 ] || echo ',' >> "$TMP"
  first=0
  jq -n --arg fork "$f" --arg repo "$target" --argjson prs "$mine" --argjson foreign "$foreign" \
     '{fork:$fork,repo:$repo,url:("https://github.com/"+$repo),prs:$prs,foreign:$foreign}' >> "$TMP"
  echo "  $target — $(echo "$mine" | jq length) yours, $(echo "$foreign" | jq length) other" >&2
done
echo ']}' >> "$TMP"
if ! jq -e . "$TMP" >/dev/null 2>&1; then
  echo "!! collected file is not valid JSON — keeping the previous data.json" >&2
  exit 1
fi
found=$(jq '[.repos[].prs[]] | length' "$TMP")
if [ "$found" -eq 0 ]; then
  echo "!! collected 0 pull requests across $(jq '.repos|length' "$TMP") repos." >&2
  echo "!! That means the token cannot see the upstream handshake-project-dynamo repos." >&2
  echo "!! Keeping the previous data.json rather than publishing an empty board." >&2
  exit 1
fi
mv "$TMP" "$OUT"
echo "wrote $OUT — $found pull requests" >&2
