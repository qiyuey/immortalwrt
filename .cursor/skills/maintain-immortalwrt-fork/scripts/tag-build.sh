#!/usr/bin/env bash
# Create an annotated build tag at HEAD.
# Naming: my/<base-tag>-<suffix>   where <base-tag> is the most recent upstream tag reachable.
# Usage: tag-build.sh <suffix> [-m "message"] [-p]
#   suffix : required, e.g. 1, 2, beta1
#   -m MSG : custom annotation message
#   -p     : also push the tag to origin
#
# Examples:
#   tag-build.sh 1                # creates my/v25.12.0-1
#   tag-build.sh 1 -m "first stable build for daily router" -p

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

PUSH=false
MSG=""
SUFFIX=""

while [ $# -gt 0 ]; do
    case "$1" in
        -p|--push)    PUSH=true; shift ;;
        -m|--message) MSG="$2"; shift 2 ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        -*) fail "unknown option: $1" ;;
        *)  if [ -z "$SUFFIX" ]; then SUFFIX="$1"; shift; else fail "extra argument: $1"; fi ;;
    esac
done

[ -n "$SUFFIX" ] || fail "missing suffix; usage: tag-build.sh <suffix> [-m MSG] [-p]"

BASE_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
[ -n "$BASE_TAG" ] || fail "no reachable upstream tag from HEAD; cannot derive base tag"

TAG="my/${BASE_TAG}-${SUFFIX}"

if git rev-parse --verify "refs/tags/$TAG" >/dev/null 2>&1; then
    fail "tag $TAG already exists; pick a new suffix"
fi

[ -n "$MSG" ] || MSG="Personal build on $BASE_TAG ($(date -Is))"

git tag -a "$TAG" -m "$MSG"
ok "Created tag $TAG  ->  $(git rev-parse --short HEAD)"

if [ "$PUSH" = true ]; then
    require_remote origin
    info "Pushing $TAG to origin..."
    git push origin "$TAG"
    ok "Pushed."
else
    echo "Push later with: git push origin $TAG"
fi
