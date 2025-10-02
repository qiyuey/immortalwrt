#!/usr/bin/env bash
# Start a new major-version branch from upstream and cherry-pick the single FIX commit.
#
# Usage: upgrade-major.sh <new-branch> [upstream-branch]
#   new-branch       the local branch to create, e.g. openwrt-26.04
#   upstream-branch  optional, the upstream branch to base on (default: same as new-branch)
#
# Example:
#   upgrade-major.sh openwrt-26.04
#
# This script does NOT delete the old branch. Keep it for 1-2 months as fallback.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

[ $# -ge 1 ] || fail "usage: upgrade-major.sh <new-branch> [upstream-branch]"

NEW_BRANCH="$1"
UP_BRANCH="${2:-$NEW_BRANCH}"
OLD_BRANCH=$(current_branch)

require_remote upstream
require_clean_tree

git show-ref --verify --quiet "refs/heads/$NEW_BRANCH" \
    && fail "branch $NEW_BRANCH already exists locally"

info "Fetching upstream..."
git fetch upstream --tags --prune --quiet

UPSTREAM_REF="upstream/$UP_BRANCH"
git rev-parse --verify "$UPSTREAM_REF" >/dev/null 2>&1 \
    || fail "$UPSTREAM_REF does not exist"

OLD_UPSTREAM_REF="upstream/$OLD_BRANCH"
git rev-parse --verify "$OLD_UPSTREAM_REF" >/dev/null 2>&1 \
    || fail "$OLD_UPSTREAM_REF not found; cannot identify FIX commit"

COUNT=$(git rev-list --count "$OLD_UPSTREAM_REF..$OLD_BRANCH")
if [ "$COUNT" -ne 1 ]; then
    fail "Source branch $OLD_BRANCH has $COUNT commits ahead of $OLD_UPSTREAM_REF; expected 1.
       Restore invariant first:
           git reset --soft $OLD_UPSTREAM_REF && git commit -m FIX"
fi

FIX_COMMIT=$(git rev-list "$OLD_UPSTREAM_REF..$OLD_BRANCH")
FIX_SHORT=$(git rev-parse --short "$FIX_COMMIT")
FIX_SUBJ=$(git log -1 --format=%s "$FIX_COMMIT")

echo
info "Plan:"
echo "  source branch :  $OLD_BRANCH (FIX = $FIX_SHORT $FIX_SUBJ)"
echo "  new branch    :  $NEW_BRANCH (from $UPSTREAM_REF @ $(git rev-parse --short "$UPSTREAM_REF"))"
echo

confirm "Proceed?" || { warn "Aborted."; exit 1; }

TS=$(date +%Y%m%d-%H%M%S)
BACKUP_TAG="backup/${OLD_BRANCH}-pre-upgrade-${TS}"
git tag "$BACKUP_TAG" "$OLD_BRANCH"
ok "Backup tag for source branch: $BACKUP_TAG"

git checkout -b "$NEW_BRANCH" "$UPSTREAM_REF"
ok "Created $NEW_BRANCH at $(git rev-parse --short HEAD)"

info "Cherry-picking FIX commit $FIX_SHORT..."
if ! git cherry-pick -x "$FIX_COMMIT"; then
    echo
    warn "Conflict cherry-picking FIX into the new major version."
    echo
    echo "To resolve:"
    echo "  - Fix conflicts, git add files, then:  git cherry-pick --continue"
    echo "  - Abort entirely:                       git cherry-pick --abort"
    echo
    echo "After --continue, verify with:  scripts/verify-single-patch.sh"
    exit 1
fi

ok "Upgrade branch ready: $NEW_BRANCH"
echo
echo "Recommended next steps:"
echo "  1. scripts/verify-single-patch.sh   # confirm invariant"
echo "  2. build & test thoroughly"
echo "  3. scripts/snapshot-build.sh        # record env after first good build"
echo "  4. Keep $OLD_BRANCH (+ tag $BACKUP_TAG) for at least 1-2 months as fallback"
