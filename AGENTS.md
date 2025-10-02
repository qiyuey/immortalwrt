# AGENTS.md

Personal fork of [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) tracking upstream `master`.

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
| Build from an existing tag        | `git checkout my/v25.12.0-N` then build; `git switch master` when done |
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
- `.agents/skills/annotate-check-config/` — explain existing configuration entries
- `scripts/checkconfig.sh`, `scripts/checkconfig.py`, `scripts/tests/test_checkconfig.py` — standalone seed generator and tests
- `.agents/skills/tag-immortalwrt-build/` — build tag workflow
- `check.config` — documented personal build configuration seed
- Intel early microcode packaging and x86 GRUB loading changes

This fork aims for **source-level reproducibility**: the `my/<tag>` annotated tags pin the main repository source state. Feed revisions are not locked by these tags. Build outputs (`bin/`, `build_dir/`, `staging_dir/`, `tmp/`) and feeds (`feeds/`) are upstream-gitignored and never committed.

Branches, remotes, and FIX commit format are documented in `.agents/skills/maintain-immortalwrt-fork/SKILL.md` and `.agents/skills/maintain-immortalwrt-fork/templates/FIX_COMMIT_MESSAGE.md`.

## 配置清单维护

使用独立脚本从当前 `.config` 生成带基础中文分组的 `check.config`，无需 LLM。
需要为已有条目补充用途和取舍说明时，使用 `.agents/skills/annotate-check-config/`；只改注释，不改配置值。
命令行入口：`./scripts/checkconfig.sh > check.config`，配置输出到 stdout，诊断输出到 stderr。
`check.config` 是唯一维护的精简配置清单，旧 `diff.config` 已移除。清单只记录功能入口、独立能力和必要的默认值覆盖；
默认关闭的项目不必单列（如未选择的 BanIP），但关闭默认驱动、镜像格式等选择必须保留。
自动依赖交给 defconfig；生成脚本只在全部有效配置值还原一致时写入清单，不覆盖用户 `.config`。
循环依赖沿用上游默认的非致命诊断；配置等价性仍必须通过检查。
应用清单时运行 `cp check.config .config && make defconfig`。

## Upstream

- Source: <https://github.com/immortalwrt/immortalwrt>
- Currently tracking: `master` against `upstream/master`

## x86 Intel early microcode

`intel-microcode` installs `/boot/intel-ucode.img` as a standard early CPIO.
BIOS/UEFI combined images (and ISO images) copy it to the boot partition and
load it through GRUB before the root filesystem is available. Keep the package
selected; do not bypass `CONFIG_MICROCODE_LATE_FORCE_MINREV` to force a late update.
GRUB provides a normal boot entry without microcode as a recovery option and
allows three seconds to select it when the configured timeout would be zero.
After reboot, verify the running revision, early-update log and RFDS mitigation;
archive validation alone does not establish that a CPU update took effect.
