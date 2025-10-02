#!/usr/bin/env bash
# Fold staged (or all) changes into the single FIX commit at HEAD.
# Enforces invariant: exactly 1 commit ahead of upstream/<current-branch>.
#
# Usage:
#   amend-fix.sh [-a] [-m "changelog line"] [--reword] [-n] [--no-verify]
#     -a              stage all tracked modifications first (git add -u)
#     -m "TEXT"       append "- TEXT" under the Changelog: section of the
#                     commit message body (creates the section if missing)
#     --reword        open editor to edit the commit message
#     -n / --dry-run  print what would happen, change nothing
#     --no-verify     pass --no-verify to git commit (skip hooks)
#
# Examples:
#   amend-fix.sh                                  # amend already-staged changes, keep msg
#   amend-fix.sh -a                               # stage all tracked + amend, keep msg
#   amend-fix.sh -a -m "enable LuCI HTTPS"        # + add changelog line
#   amend-fix.sh --reword                         # interactive msg edit
#   amend-fix.sh -n -a -m "new package"           # dry-run

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

ADD_ALL=false
CHANGELOG=""
REWORD=false
DRY_RUN=false
NO_VERIFY=""

while [ $# -gt 0 ]; do
    case "$1" in
        -a)            ADD_ALL=true; shift ;;
        -m|--message)  [ -n "${2:-}" ] || fail "-m requires an argument"
                       CHANGELOG="$2"; shift 2 ;;
        --reword)      REWORD=true; shift ;;
        -n|--dry-run)  DRY_RUN=true; shift ;;
        --no-verify)   NO_VERIFY="--no-verify"; shift ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) fail "unknown arg: $1" ;;
    esac
done

BRANCH=$(current_branch)
require_remote upstream

UPSTREAM_REF="upstream/$BRANCH"
git rev-parse --verify "$UPSTREAM_REF" >/dev/null 2>&1 \
    || fail "$UPSTREAM_REF not found; run: git fetch upstream"

COUNT=$(git rev-list --count "$UPSTREAM_REF..HEAD")
case "$COUNT" in
    0) info "0 commits ahead of $UPSTREAM_REF — will create a fresh FIX commit." ;;
    1) ok   "Invariant holds: 1 commit ahead of $UPSTREAM_REF." ;;
    *) fail "INVARIANT VIOLATED: $COUNT commits ahead of $UPSTREAM_REF (expected 1).
       Restore with:
           git reset --soft $UPSTREAM_REF && git commit -m FIX
       Then re-run this script." ;;
esac

# Optionally stage all tracked modifications.
if [ "$ADD_ALL" = true ]; then
    info "Staging all tracked modifications (git add -u)..."
    git add -u
fi

STAGED_FILES=$(git diff --cached --name-only)

# If nothing to do, refuse early (unless we're just rewording).
if [ -z "$STAGED_FILES" ] && [ -z "$CHANGELOG" ] && [ "$REWORD" = false ]; then
    fail "Nothing staged. Stage files (git add ...) or pass -a; or use --reword to edit message only."
fi

# Build the message file when we need to modify the commit body.
MSG_FILE=""
NEED_MSG=false
if [ -n "$CHANGELOG" ] || { [ "$COUNT" -eq 0 ] && [ -z "$CHANGELOG" ] && [ "$REWORD" = false ]; }; then
    NEED_MSG=true
fi

if [ "$NEED_MSG" = true ]; then
    MSG_FILE=$(mktemp)
    trap 'rm -f "$MSG_FILE" "${MSG_FILE}.new"' EXIT

    if [ "$COUNT" -ge 1 ]; then
        git log -1 --format=%B HEAD > "$MSG_FILE"
        # Strip trailing blank lines for clean append.
        awk 'BEGIN{p=0} /^$/{b=b $0 "\n"; next} {printf "%s%s\n", b, $0; b=""}' "$MSG_FILE" > "${MSG_FILE}.new"
        mv "${MSG_FILE}.new" "$MSG_FILE"
    else
        cat > "$MSG_FILE" <<'EOF'
FIX

Personal patches and configuration on top of upstream.

Changelog:
EOF
    fi

    if [ -n "$CHANGELOG" ]; then
        if grep -q '^Changelog:' "$MSG_FILE"; then
            awk -v line="- $CHANGELOG" '
                { print }
                /^Changelog:/ && !done { print line; done=1 }
            ' "$MSG_FILE" > "${MSG_FILE}.new"
        else
            cp "$MSG_FILE" "${MSG_FILE}.new"
            printf '\nChangelog:\n- %s\n' "$CHANGELOG" >> "${MSG_FILE}.new"
        fi
        mv "${MSG_FILE}.new" "$MSG_FILE"
    fi
fi

# Compose final git commit invocation.
declare -a GIT_ARGS
if [ "$COUNT" -ge 1 ]; then
    GIT_ARGS=(commit --amend)
    if [ "$NEED_MSG" = true ]; then
        GIT_ARGS+=(-F "$MSG_FILE")
        [ "$REWORD" = true ] && GIT_ARGS+=(--edit)
    elif [ "$REWORD" = true ]; then
        : # default editor opens with existing message
    else
        GIT_ARGS+=(--no-edit)
    fi
else
    GIT_ARGS=(commit)
    if [ "$NEED_MSG" = true ]; then
        GIT_ARGS+=(-F "$MSG_FILE")
    else
        GIT_ARGS+=(-m FIX)
    fi
fi
[ -n "$NO_VERIFY" ] && GIT_ARGS+=("$NO_VERIFY")

if [ "$DRY_RUN" = true ]; then
    info "DRY RUN — would run:"
    echo "  git ${GIT_ARGS[*]}"
    echo
    info "Staged changes:"
    git diff --cached --name-status || true
    if [ "$NEED_MSG" = true ]; then
        echo
        info "Proposed commit message:"
        sed 's/^/    /' "$MSG_FILE"
    fi
    exit 0
fi

git "${GIT_ARGS[@]}"

# Final invariant re-check (defensive).
POST_COUNT=$(git rev-list --count "$UPSTREAM_REF..HEAD")
if [ "$POST_COUNT" -ne 1 ]; then
    warn "Post-amend count is $POST_COUNT (expected 1). Investigate."
fi

ok "FIX commit updated:"
git log -1 --format='  %h %s' HEAD
echo
echo "Inspect:  scripts/verify-single-patch.sh"
echo "Push:     git push --force-with-lease   (or: git pushf)"
