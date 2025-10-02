#!/usr/bin/env bash
# Assert the single-patch invariant and print the FIX commit.
# Exit codes:
#   0  exactly 1 commit ahead of upstream/<current-branch>
#   2  0 commits ahead (no FIX commit present)
#   1  any other violation (>1 commits, missing upstream ref, etc.)
#
# Usage: verify-single-patch.sh [branch]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

BRANCH="${1:-$(current_branch)}"
require_remote upstream

UPSTREAM_REF="upstream/$BRANCH"
git rev-parse --verify "$UPSTREAM_REF" >/dev/null 2>&1 \
    || fail "$UPSTREAM_REF not found; run: git fetch upstream"

COUNT=$(git rev-list --count "$UPSTREAM_REF..HEAD")

case "$COUNT" in
    0)
        warn "0 commits ahead of $UPSTREAM_REF — no FIX commit present."
        exit 2 ;;
    1)
        ok "Invariant holds: exactly 1 commit ahead of $UPSTREAM_REF." ;;
    *)
        printf "${C_RED}INVARIANT VIOLATED${C_RESET}: %s commits ahead of %s (expected 1).\n" "$COUNT" "$UPSTREAM_REF" >&2
        echo "Offending commits:" >&2
        git log --oneline "$UPSTREAM_REF..HEAD" >&2
        echo >&2
        echo "Restore with:" >&2
        echo "  git reset --soft $UPSTREAM_REF && git commit -m FIX" >&2
        echo "(amend back the proper changelog body afterwards via scripts/amend-fix.sh --reword)" >&2
        exit 1 ;;
esac

echo
info "FIX commit (HEAD):"
echo "  $(git log -1 --format='%h %s')"
echo

info "Commit message body:"
git log -1 --format=%B HEAD | sed 's/^/    /'

echo
info "Files changed in FIX (vs upstream):"
git diff --stat "$UPSTREAM_REF..HEAD"
