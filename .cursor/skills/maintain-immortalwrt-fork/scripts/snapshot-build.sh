#!/usr/bin/env bash
# Record a reproducibility snapshot of the current build environment.
# Output: build-snapshots/<label>.txt   (label defaults to a timestamp)
# Usage: snapshot-build.sh [label]
#
# Captures: HEAD commit, upstream base, LOCAL patches list, .config sha256,
# feeds.conf, per-feed git revisions, version.buildinfo (if produced).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

LABEL="${1:-$(date +%Y%m%d-%H%M%S)}"
OUT_DIR="build-snapshots"
OUT_FILE="$OUT_DIR/${LABEL}.txt"
mkdir -p "$OUT_DIR"

BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo detached)"
UPSTREAM_REF=""
if [ "$BRANCH" != "detached" ] && git rev-parse --verify "upstream/$BRANCH" >/dev/null 2>&1; then
    UPSTREAM_REF="upstream/$BRANCH"
fi

{
    echo "# Build Snapshot: $LABEL"
    echo "Generated: $(date -Is)"
    echo "Host:      $(hostname)"
    echo

    echo "## Repository"
    echo "branch:    $BRANCH"
    echo "HEAD:      $(git rev-parse HEAD)"
    echo "describe:  $(git describe --tags --always --dirty)"
    echo "remote (origin):   $(git remote get-url origin 2>/dev/null || echo none)"
    echo "remote (upstream): $(git remote get-url upstream 2>/dev/null || echo none)"
    echo

    if [ -n "$UPSTREAM_REF" ]; then
        echo "## Upstream base"
        echo "$UPSTREAM_REF: $(git rev-parse "$UPSTREAM_REF")"
        echo "merge-base:    $(git merge-base HEAD "$UPSTREAM_REF")"
        echo
    fi

    echo "## LOCAL patches (subject lines)"
    if [ -n "$UPSTREAM_REF" ]; then
        git log --oneline "$UPSTREAM_REF..HEAD" 2>/dev/null || true
    else
        git log --grep='^\[LOCAL\]' --oneline 2>/dev/null || true
    fi
    echo

    echo "## .config"
    if [ -f .config ]; then
        echo "size:    $(wc -c < .config) bytes"
        echo "sha256:  $(sha256sum .config | awk '{print $1}')"
    else
        echo "(.config not present)"
    fi
    echo

    echo "## feeds.conf"
    for f in feeds.conf feeds.conf.default; do
        if [ -f "$f" ]; then
            echo "--- $f  sha256=$(sha256sum "$f" | awk '{print $1}') ---"
            cat "$f"
            echo
        fi
    done

    echo "## Per-feed revisions"
    if [ -d feeds ]; then
        for d in feeds/*/; do
            [ -d "$d" ] || continue
            name=$(basename "$d")
            if [ -d "$d/.git" ] || [ -f "$d/.git" ]; then
                rev=$(git -C "$d" rev-parse HEAD 2>/dev/null || echo unknown)
                desc=$(git -C "$d" describe --tags --always --dirty 2>/dev/null || echo "")
                printf "  %-24s %s   %s\n" "$name" "$rev" "$desc"
            fi
        done
    else
        echo "(no feeds/ directory; run ./scripts/feeds update -a first)"
    fi
    echo

    echo "## version.buildinfo (if a build has been produced)"
    if ls bin/targets/*/*/version.buildinfo >/dev/null 2>&1; then
        for vbi in bin/targets/*/*/version.buildinfo; do
            echo "--- $vbi ---"
            cat "$vbi"
        done
    else
        echo "(no version.buildinfo found under bin/targets/)"
    fi
    echo

    echo "## sha256sums of produced images (if any)"
    if ls bin/targets/*/*/sha256sums >/dev/null 2>&1; then
        for s in bin/targets/*/*/sha256sums; do
            echo "--- $s ---"
            cat "$s"
        done
    else
        echo "(no sha256sums file found)"
    fi
} | tee "$OUT_FILE" >/dev/null

ok "Snapshot saved: $OUT_FILE"
echo
echo "Tip: commit it (or at least keep it) so future builds can be reproduced."
