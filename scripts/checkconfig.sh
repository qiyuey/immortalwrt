#!/bin/sh
# Emit a validated configuration seed on stdout; diagnostics go to stderr.
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0 > check.config" >&2
    exit 2
fi

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

python3 "$root/scripts/checkconfig.py" \
    --output "$work/check.config" >&2
cat "$work/check.config"
