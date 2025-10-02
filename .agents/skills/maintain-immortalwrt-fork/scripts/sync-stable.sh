#!/usr/bin/env bash
# Rebase current branch onto upstream/<same-name> with a safety backup tag.
# Usage: sync-stable.sh [branch]   (defaults to current branch)
#
# This script intentionally NEVER pushes. After it finishes, run:
#   git push --force-with-lease    (or: git pushf  if setup-repo.sh has been run)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

BRANCH="${1:-$(current_branch)}"
require_remote upstream
require_clean_tree

if [ "$(current_branch)" != "$BRANCH" ]; then
    info "Switching to branch $BRANCH"
    git checkout "$BRANCH"
fi

info "Fetching upstream (tags + prune)..."
git fetch upstream --tags --prune --quiet

UPSTREAM_REF="upstream/$BRANCH"
if ! git rev-parse --verify "$UPSTREAM_REF" >/dev/null 2>&1; then
    fail "upstream branch $UPSTREAM_REF does not exist"
fi

# Fast-path: already up to date.
if git merge-base --is-ancestor "$UPSTREAM_REF" HEAD; then
    ok "Already up to date with $UPSTREAM_REF (your branch contains everything upstream has)."
    exit 0
fi

# Show pending commits
INCOMING=$(git rev-list --count "$BRANCH..$UPSTREAM_REF")
info "$INCOMING upstream commit(s) to bring in:"
echo
git log --oneline --decorate "$BRANCH..$UPSTREAM_REF" | head -60
[ "$INCOMING" -gt 60 ] && echo "... ($((INCOMING - 60)) more)"
echo

LOCAL_AHEAD=$(git rev-list --count "$UPSTREAM_REF..$BRANCH")
info "$LOCAL_AHEAD local commit(s) will be replayed on top:"
git log --oneline --decorate "$UPSTREAM_REF..$BRANCH"
echo

confirm "Proceed with rebase?" || { warn "Aborted."; exit 1; }

# Safety backup tag
TS=$(date +%Y%m%d-%H%M%S)
BACKUP_TAG="backup/${BRANCH}-${TS}"
git tag "$BACKUP_TAG"
ok "Safety backup tag created: $BACKUP_TAG"

# Rebase
if git rebase "$UPSTREAM_REF"; then
    echo
    ok "Rebase complete. New HEAD: $(git rev-parse --short HEAD)"
    echo
    echo "Next steps:"
    echo "  1. Test build / inspect changes."
    echo "  2. Push with: git push --force-with-lease   (or 'git pushf' after setup-repo.sh)"
    echo "  3. Delete backup when satisfied: git tag -d $BACKUP_TAG"
else
    echo
    warn "Rebase has conflicts."
    echo
    echo "To resolve:"
    echo "  - Fix files listed by 'git status', then: git add <file> && git rebase --continue"
    echo "  - Skip the current conflicting commit:                git rebase --skip"
    echo "  - Abort entirely and return to pre-rebase state:      git rebase --abort"
    echo
    echo "Safety net: backup tag = $BACKUP_TAG"
    exit 1
fi
