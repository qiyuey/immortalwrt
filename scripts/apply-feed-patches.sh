#!/usr/bin/env bash
# Reapply tracked feed fixes after cloning/updating and before metadata scanning.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
for feed in "$@"; do
    for patch in "$root/patches/feeds/$feed/"*.patch; do
        [ -f "$patch" ] || continue
        if git -C "$root/feeds/$feed" apply --reverse --check "$patch" 2>/dev/null; then
            continue
        fi
        if ! git -C "$root/feeds/$feed" apply --check "$patch"; then
            echo "Feed patch needs review: $patch" >&2
            exit 1
        fi
        git -C "$root/feeds/$feed" apply "$patch"
        echo "Applied feed patch: $feed/$(basename "$patch")"
    done
done
