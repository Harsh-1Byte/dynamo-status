#!/usr/bin/env bash
# Re-pull status from GitHub and rebuild the board.
set -euo pipefail
cd "$(dirname "$0")"
./collect.sh
python3 build.py
echo "open file://$(pwd)/index.html"
