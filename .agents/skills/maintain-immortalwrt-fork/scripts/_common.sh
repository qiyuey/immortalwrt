#!/usr/bin/env bash
# Shared helpers sourced by other scripts in this directory.
# Do not execute directly.

set -euo pipefail

# Locate repo root regardless of CWD.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
    echo "Error: not inside a git repository." >&2
    exit 1
fi
cd "$REPO_ROOT"

# Color helpers (no-op if not a tty)
if [ -t 1 ]; then
    C_RED='\033[31m'; C_GREEN='\033[32m'; C_YELLOW='\033[33m'
    C_BLUE='\033[34m'; C_BOLD='\033[1m'; C_RESET='\033[0m'
else
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_BOLD=''; C_RESET=''
fi
info()  { printf "${C_BLUE}==>${C_RESET} %s\n" "$*"; }
ok()    { printf "${C_GREEN}OK${C_RESET}  %s\n" "$*"; }
warn()  { printf "${C_YELLOW}WARN${C_RESET} %s\n" "$*"; }
fail()  { printf "${C_RED}ERR${C_RESET} %s\n" "$*" >&2; exit 1; }

current_branch() {
    git symbolic-ref --short HEAD 2>/dev/null || fail "detached HEAD; checkout a branch first"
}

require_clean_tree() {
    if [ -n "$(git status --porcelain)" ]; then
        fail "working tree not clean; commit or stash first"
    fi
}

require_remote() {
    local remote="$1"
    git remote get-url "$remote" >/dev/null 2>&1 || \
        fail "remote '$remote' not configured (expected: upstream + origin)"
}

confirm() {
    local prompt="${1:-Continue?}"
    local ans
    read -rp "$prompt [y/N] " ans
    [[ "${ans:-}" == "y" || "${ans:-}" == "Y" ]]
}
