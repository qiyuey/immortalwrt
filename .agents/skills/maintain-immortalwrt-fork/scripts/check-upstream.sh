#!/usr/bin/env bash
# Read-only preview: what would sync-stable.sh bring in?
# Usage: check-upstream.sh [branch]   (defaults to current branch)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

BRANCH="${1:-$(current_branch)}"
require_remote upstream

info "Fetching upstream (tags + prune)..."
git fetch upstream --tags --prune --quiet

UPSTREAM_REF="upstream/$BRANCH"
if ! git rev-parse --verify "$UPSTREAM_REF" >/dev/null 2>&1; then
    fail "upstream branch $UPSTREAM_REF does not exist"
fi

LOCAL_HEAD=$(git rev-parse --short HEAD)
LOCAL_SUBJ=$(git log -1 --format=%s)
UP_HEAD=$(git rev-parse --short "$UPSTREAM_REF")
UP_SUBJ=$(git log -1 --format=%s "$UPSTREAM_REF")

echo
printf "${C_BOLD}Branch:${C_RESET}        %s\n" "$BRANCH"
printf "${C_BOLD}Local HEAD:${C_RESET}    %s  %s\n" "$LOCAL_HEAD" "$LOCAL_SUBJ"
printf "${C_BOLD}Upstream HEAD:${C_RESET} %s  %s\n" "$UP_HEAD" "$UP_SUBJ"

# Merge base info
MB=$(git merge-base HEAD "$UPSTREAM_REF")
MB_SHORT=$(git rev-parse --short "$MB")
echo
info "Merge base: $MB_SHORT"

# Pending upstream commits
INCOMING=$(git rev-list --count "$BRANCH..$UPSTREAM_REF")
LOCAL_AHEAD=$(git rev-list --count "$UPSTREAM_REF..$BRANCH")
printf "Pending from upstream: ${C_BOLD}%s${C_RESET}    Local commits ahead: ${C_BOLD}%s${C_RESET}\n" "$INCOMING" "$LOCAL_AHEAD"

if [ "$INCOMING" -gt 0 ]; then
    echo
    info "Incoming upstream commits ($BRANCH..$UPSTREAM_REF):"
    git log --oneline --decorate "$BRANCH..$UPSTREAM_REF" | head -50
    if [ "$INCOMING" -gt 50 ]; then
        echo "... ($((INCOMING - 50)) more)"
    fi
fi

if [ "$LOCAL_AHEAD" -gt 0 ]; then
    echo
    info "Your local commits on top of upstream:"
    git log --oneline --decorate "$UPSTREAM_REF..$BRANCH"
fi

# Newer tags
echo
info "Recent upstream tags reachable from $UPSTREAM_REF:"
git tag --sort=-v:refname --merged "$UPSTREAM_REF" | head -8

LAST_LOCAL_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
if [ -n "$LAST_LOCAL_TAG" ]; then
    echo
    info "Most recent tag reachable from HEAD: $LAST_LOCAL_TAG"
fi

echo
if [ "$INCOMING" -eq 0 ]; then
    ok "Already up to date with $UPSTREAM_REF."
else
    info "To sync, run: scripts/sync-stable.sh"
fi
