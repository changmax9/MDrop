#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -eq 0 ]]; then
  open "mdrop://new"
else
  open -a MDrop -- "$@"
fi
