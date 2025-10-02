---
name: maintain-immortalwrt-fork
description: Maintain a personal ImmortalWrt fork that tracks an upstream stable branch (openwrt-25.12 / openwrt-26.xx) with EXACTLY ONE patch commit named FIX on top. Use when syncing with upstream stable, previewing pending upstream changes, amending personal changes into the single FIX commit, verifying the single-commit invariant, tagging a build for reproducible source, upgrading across major versions, or recovering from a bad rebase. Prefers the bundled scripts under scripts/ for all git-mutating operations.
---

# Maintain ImmortalWrt Fork

This skill maintains a single-person ImmortalWrt fork that follows the upstream **stable branch** (e.g. `openwrt-25.12`) and keeps **exactly one** personal patch commit on top, named `FIX`.

**Always prefer the scripts under `scripts/`** over crafting raw git commands. The scripts already enforce the invariant, handle safety backup tags, working-tree cleanliness checks, branch auto-detection, dry-run preview, and conflict guidance.

## Hard invariants

1. **Exactly one commit ahead of `upstream/<current-branch>`**, subject `FIX`. NEVER create a second personal commit.
2. **All personal changes — code, config, scripts, AGENTS.md, this skill itself — are folded into that single FIX commit via `git commit --amend`.**
3. **Never push to `upstream`.** Only `origin` is for this fork.
4. **Use `git push --force-with-lease`**, never `git push -f`.

If you ever end up with >1 commit ahead of upstream, restore the invariant:

```bash
git reset --soft upstream/<current-branch>
git commit -m FIX
# then re-add a proper body / changelog
```

## Branch model

```
upstream/openwrt-25.12    (read-only, stable branch we follow)
        │
        ▼
origin/openwrt-25.12      (our fork, force-pushed after each rebase)
        │
        └── FIX commit  ← all personal changes squashed here
              │
              └── my/v25.12.x-N tags  (anchor points for actual builds)
```

Rules:
- **Track the stable branch**, not a frozen tag — gets CVE/driver backports.
- **Anchor each real build with a `my/<base-tag>-N` tag**, so any build is reproducible.
- **One branch per major version.** Upgrades (25.12 → 26.xx) go to a NEW branch via `upgrade-major.sh`.

## First-time setup

Run once per clone:

```bash
.agents/skills/maintain-immortalwrt-fork/scripts/setup-repo.sh
```

Configures `rerere`, disables push to `upstream`, adds aliases, verifies remotes.

## Routine workflows

### A. Add or modify ANY personal change

This is the most common operation. Whether the change is `.config`, a package Makefile, a patch, AGENTS.md, or this skill itself — fold it into FIX:

```bash
# stage your changes (or pass -a to stage all tracked modifications)
git add <files>

# amend into FIX, optionally with a changelog line for the body
.agents/skills/maintain-immortalwrt-fork/scripts/amend-fix.sh -m "added xray-core to default image"
```

The script:
1. Verifies invariant (exactly 1 commit ahead of upstream).
2. Amends staged changes into HEAD.
3. With `-m`, appends `- <text>` to a `Changelog:` section in the commit message body (preserves existing changelog).
4. Refuses if working tree has 2+ commits ahead (would violate invariant).

Common usage:

```bash
amend-fix.sh                              # amend already-staged changes, keep msg
amend-fix.sh -a                           # stage all tracked + amend
amend-fix.sh -a -m "enable LuCI HTTPS"    # + append changelog line
amend-fix.sh --reword                     # open editor to edit FIX msg
amend-fix.sh -n -a                        # dry-run: show what would happen
```

### B. Verify the single-commit invariant

```bash
.agents/skills/maintain-immortalwrt-fork/scripts/verify-single-patch.sh
```

Exits 0 if exactly 1 commit ahead. Prints the FIX commit subject + body. Run after any unusual git operation (rebase, cherry-pick, manual commits).

### C. Check what's new upstream (read-only)

```bash
.agents/skills/maintain-immortalwrt-fork/scripts/check-upstream.sh
```

### D. Sync with upstream stable branch

```bash
.agents/skills/maintain-immortalwrt-fork/scripts/sync-stable.sh
```

What it does:
1. Refuses if working tree is dirty.
2. `git fetch upstream --tags --prune`.
3. Prints pending upstream commits and asks for confirmation.
4. Creates a safety backup tag `backup/<branch>-<timestamp>`.
5. `git rebase upstream/<current-branch>` (FIX rides up to the new HEAD).
6. On conflict: pauses with instructions.

After success, manually push:

```bash
git push --force-with-lease     # or 'git pushf' after setup-repo.sh
```

### E. Tag a build (stable source anchor)

When you produce firmware you intend to flash, create an annotated tag so the
source state is recoverable later. The tag IS the reproducibility guarantee —
`git checkout my/<tag>` gives identical source at any time.

```bash
.agents/skills/maintain-immortalwrt-fork/scripts/tag-build.sh 1 -p
# -> creates my/<latest-upstream-tag>-1 and pushes to origin
```

To build from a tag later:

```bash
git checkout my/v25.12.0-1     # detached HEAD is intentional / correct
# ./scripts/feeds update -a && ./scripts/feeds install -a
# cp diff.config .config && make defconfig
# make -j$(nproc)
git switch openwrt-25.12        # back to branch when done
```

Note: this fork chooses **source-level reproducibility** (same tag = same code)
rather than bit-level reproducibility. Feed revisions and toolchain may drift
between builds of the same tag.

### F. Major version upgrade (rare)

```bash
.agents/skills/maintain-immortalwrt-fork/scripts/upgrade-major.sh openwrt-26.04
```

Creates a new branch from `upstream/openwrt-26.04` and cherry-picks the single FIX commit. Keep the old major branch (`openwrt-25.12`) for at least 1–2 months as fallback.

## FIX commit message format

Subject is always `FIX`. Body is a free-form description with a `Changelog:` section. See `templates/FIX_COMMIT_MESSAGE.md` for a worked example. The `amend-fix.sh -m` flag maintains this format automatically.

Recommended changelog tags:

| Tag | Use for |
|-----|---------|
| `[config]`  | Default `.config`, feeds.conf, build defaults |
| `[feat]`    | New features / capabilities |
| `[fix]`     | Workarounds for upstream bugs (note expected drop point) |
| `[pkg]`     | Adding/removing/modifying packages |
| `[tune]`    | Performance / size tuning |
| `[tooling]` | Meta: scripts, AGENTS.md, this skill, docs |

## Recovery

Every `sync-stable.sh` run creates `backup/<branch>-<timestamp>`. If a rebase goes wrong AFTER pushing:

```bash
git reset --hard backup/<branch>-<timestamp>
git push --force-with-lease
```

If invariant breaks (>1 commit ahead) after a botched cherry-pick / interactive rebase:

```bash
git reset --soft upstream/<current-branch>
git commit -m FIX
# restore the changelog body via: git commit --amend
```

List safety backups:

```bash
git tag --list 'backup/*' --sort=-creatordate
```

## When to surface this skill proactively

The agent should follow this skill whenever the user:
- asks to "sync with upstream", "rebase", "update from upstream", "拉一下上游", "同步上游"
- adds, removes, or edits ANY file in the repo (the change must be amended into FIX)
- is about to run `git commit`, `git rebase`, `git pull --rebase`, or `git push -f`
- mentions building firmware, recording build info, or "打 tag"
- asks to upgrade to a newer ImmortalWrt major version

## Reference

- `scripts/_common.sh` — shared helpers (sourced by others)
- `scripts/setup-repo.sh` — one-time git config, idempotent
- `scripts/check-upstream.sh` — read-only preview, safe anytime
- `scripts/sync-stable.sh` — rebase current branch on `upstream/<same-name>` with safety tag
- `scripts/amend-fix.sh` — fold staged changes into FIX, optionally updating the changelog
- `scripts/verify-single-patch.sh` — assert invariant + print FIX body
- `scripts/tag-build.sh <suffix> [-p]` — create (and optionally push) `my/<latest-upstream-tag>-<suffix>` tag
- `scripts/upgrade-major.sh <new-branch> [upstream-branch]` — fork a new major branch + cherry-pick FIX
- `templates/FIX_COMMIT_MESSAGE.md` — recommended FIX commit message body format
