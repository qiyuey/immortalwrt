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
.agents/skills/maintain-immortalwrt-fork/scripts/amend-fix.sh --reword
```

## Where the workflow lives

All maintenance is encapsulated in the **`maintain-immortalwrt-fork`** skill at `.agents/skills/maintain-immortalwrt-fork/`. **Read its `SKILL.md` and prefer the scripts under `scripts/`** over crafting raw git commands. The scripts enforce the invariant, create safety backup tags, check working tree cleanliness, auto-detect the current branch, and provide dry-run previews. Codex discovers repo skills from the real `.agents/skills/` directory.

## Quick reference

| Task                              | Command |
|-----------------------------------|---------|
| Add or modify ANY personal change | `git add <files> && .agents/skills/maintain-immortalwrt-fork/scripts/amend-fix.sh -m "what changed"` |
| Stage everything and amend        | `.agents/skills/maintain-immortalwrt-fork/scripts/amend-fix.sh -a -m "what changed"` |
| Verify single-commit invariant    | `.agents/skills/maintain-immortalwrt-fork/scripts/verify-single-patch.sh` |
| Preview pending upstream changes  | `.agents/skills/maintain-immortalwrt-fork/scripts/check-upstream.sh` |
| Sync with upstream                | `.agents/skills/maintain-immortalwrt-fork/scripts/sync-stable.sh` then `git push --force-with-lease` |
| Tag a build (stable source anchor)| `.agents/skills/maintain-immortalwrt-fork/scripts/tag-build.sh N -p` |
| Build from an existing tag        | `git checkout my/v25.12.0-N` then build; `git switch openwrt-25.12` when done |
| Upgrade to new major version      | `.agents/skills/maintain-immortalwrt-fork/scripts/upgrade-major.sh openwrt-26.xx` |
| First-time clone setup            | `.agents/skills/maintain-immortalwrt-fork/scripts/setup-repo.sh` |

## Common pitfalls to avoid

- **Do not** `git commit` to create a new patch on top of FIX — always `amend-fix.sh` (which calls `git commit --amend`).
- **Do not** `git push -f`; use `--force-with-lease` (or `git pushf` alias after running `setup-repo.sh`).
- **Do not** rebase across major versions on the same branch; use `upgrade-major.sh` to fork a new branch.
- **Do not** manually edit the FIX commit message with `git commit --amend` directly — use `amend-fix.sh -m "..."` or `amend-fix.sh --reword` so the `Changelog:` section stays well-formatted.

## What lives in the FIX commit

Everything in this fork that isn't upstream code:

- `AGENTS.md` — this file
- `.agents/skills/maintain-immortalwrt-fork/` — workflow skill + scripts
- `diff.config` — personal build configuration overrides

This fork aims for **source-level reproducibility**: the `my/<tag>` annotated tags pin the source state. Build outputs (`bin/`, `build_dir/`, `staging_dir/`, `tmp/`) and feeds (`feeds/`) are upstream-gitignored and never committed.

Branches, remotes, and FIX commit format are documented in `.agents/skills/maintain-immortalwrt-fork/SKILL.md` and `.agents/skills/maintain-immortalwrt-fork/templates/FIX_COMMIT_MESSAGE.md`.

## Upstream

- Source: <https://github.com/immortalwrt/immortalwrt>
- Currently tracking: `openwrt-25.12` (latest stable tag at fork creation: `v25.12.0`)
