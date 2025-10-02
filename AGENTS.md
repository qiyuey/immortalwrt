# AGENTS.md

Personal fork of [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) tracking the upstream stable branch (currently `openwrt-25.12`).

## Hard invariants — MUST follow

1. **Exactly one commit ahead of `upstream/<current-branch>`**, subject `FIX`. **NEVER create a second personal commit.** Every change — code, config, scripts, this file, the skill itself — is folded into that single FIX commit via `git commit --amend`.
2. **Never push to `upstream`.** Only `origin` (`git@github.com:qiyuey/immortalwrt.git`) is for this fork.
3. **Use `git push --force-with-lease`**, never `git push -f`.
4. **Do not** create a separate `LOCAL-PATCHES.md` — the changelog lives in the FIX commit message body.

If you ever end up with >1 commit ahead of upstream, restore the invariant:

```bash
git reset --soft upstream/$(git symbolic-ref --short HEAD)
git commit -m FIX
.cursor/skills/maintain-immortalwrt-fork/scripts/amend-fix.sh --reword
```

## Where the workflow lives

All maintenance is encapsulated in the **`maintain-immortalwrt-fork`** skill at `.cursor/skills/maintain-immortalwrt-fork/`. **Read its `SKILL.md` and prefer the scripts under `scripts/`** over crafting raw git commands. The scripts enforce the invariant, create safety backup tags, check working tree cleanliness, auto-detect the current branch, and provide dry-run previews.

## Quick reference

| Task                              | Command |
|-----------------------------------|---------|
| Add or modify ANY personal change | `git add <files> && .cursor/skills/maintain-immortalwrt-fork/scripts/amend-fix.sh -m "what changed"` |
| Stage everything and amend        | `.cursor/skills/maintain-immortalwrt-fork/scripts/amend-fix.sh -a -m "what changed"` |
| Verify single-commit invariant    | `.cursor/skills/maintain-immortalwrt-fork/scripts/verify-single-patch.sh` |
| Preview pending upstream changes  | `.cursor/skills/maintain-immortalwrt-fork/scripts/check-upstream.sh` |
| Sync with upstream                | `.cursor/skills/maintain-immortalwrt-fork/scripts/sync-stable.sh` then `git push --force-with-lease` |
| Record build snapshot             | `.cursor/skills/maintain-immortalwrt-fork/scripts/snapshot-build.sh` |
| Tag and push a build              | `.cursor/skills/maintain-immortalwrt-fork/scripts/tag-build.sh N -p` |
| Upgrade to new major version      | `.cursor/skills/maintain-immortalwrt-fork/scripts/upgrade-major.sh openwrt-26.xx` |
| First-time clone setup            | `.cursor/skills/maintain-immortalwrt-fork/scripts/setup-repo.sh` |

## Common pitfalls to avoid

- **Do not** `git commit` to create a new patch on top of FIX — always `amend-fix.sh` (which calls `git commit --amend`).
- **Do not** `git push -f`; use `--force-with-lease` (or `git pushf` alias after running `setup-repo.sh`).
- **Do not** rebase across major versions on the same branch; use `upgrade-major.sh` to fork a new branch.
- **Do not** manually edit the FIX commit message with `git commit --amend` directly — use `amend-fix.sh -m "..."` or `amend-fix.sh --reword` so the `Changelog:` section stays well-formatted.

## What lives in the FIX commit

Everything in this fork that isn't upstream code:

- `AGENTS.md` — this file
- `.cursor/skills/maintain-immortalwrt-fork/` — workflow skill + scripts
- `diff.config` — personal build configuration overrides
- (optionally) `build-snapshots/*.txt` — reproducibility records, if you choose to track them

Branches, remotes, and FIX commit format are documented in `.cursor/skills/maintain-immortalwrt-fork/SKILL.md` and `.cursor/skills/maintain-immortalwrt-fork/templates/FIX_COMMIT_MESSAGE.md`.

## Upstream

- Source: <https://github.com/immortalwrt/immortalwrt>
- Currently tracking: `openwrt-25.12` (latest stable tag at fork creation: `v25.12.0`)
