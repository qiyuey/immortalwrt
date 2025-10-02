#!/usr/bin/env bash
# One-time (idempotent) git config for an immortalwrt fork.
# Safe to re-run.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

info "Configuring rerere (record + auto-apply repeated conflict resolutions)"
git config rerere.enabled true
git config rerere.autoupdate true

info "Configuring fetch to always pull tags from upstream"
require_remote upstream
git config remote.upstream.tagopt --tags

info "Disabling push to upstream remote (safety)"
if git remote get-url --push upstream >/dev/null 2>&1; then
    current_push=$(git remote get-url --push upstream)
    if [ "$current_push" != "DISABLED" ]; then
        git remote set-url --push upstream DISABLED
        ok "upstream push URL set to DISABLED"
    else
        ok "upstream push already disabled"
    fi
fi

info "Setting safer force-push default (force-with-lease)"
git config alias.pushf 'push --force-with-lease'

info "Adding helper aliases"
git config alias.lol 'log --graph --oneline --decorate'
git config alias.lola 'log --graph --oneline --decorate --all'
git config alias.local-patches "log --grep=^\\\\[LOCAL\\\\] --oneline"

info "Extending reflog retention to 365 days (recoverable history)"
git config gc.reflogExpire '365.days'
git config gc.reflogExpireUnreachable '90.days'

info "Verifying remotes"
git remote -v
echo

require_remote origin
require_remote upstream

ok "Setup complete."
echo
echo "Recommended next steps:"
echo "  - Use 'git pushf' instead of 'git push -f' for force-push with lease."
echo "  - Run scripts/check-upstream.sh to preview new upstream commits."
