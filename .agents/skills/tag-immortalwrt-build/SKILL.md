---
name: tag-immortalwrt-build
description: Create and verify personal ImmortalWrt build tags that combine the latest reachable upstream release tag with the fork's single FIX commit. Use when the user asks to create a my/vX.Y.Z-N tag, tag a firmware build, anchor a reproducible source state, or turn an upstream tag plus local FIX into a personal build tag.
---

# Tag ImmortalWrt Build

Use this skill to create a source anchor for a firmware build in this fork. The tag name is derived from the latest reachable release tag, and the tag object points at the current `HEAD`, which must be the single local `FIX` commit on top of `upstream/<current-branch>`.

## Invariants

- Preserve the repository invariant from `../maintain-immortalwrt-fork/SKILL.md`: exactly one local commit ahead of `upstream/<current-branch>`, with subject `FIX`.
- Never tag upstream directly. The personal tag must point to the current `FIX` commit.
- Use annotated tags named `my/<base-tag>-<suffix>`, for example `my/v25.12.1-1`.
- Push only to `origin`; never push to `upstream`.

## Workflow

1. Inspect the repository state:

```bash
git status --short --branch
.agents/skills/maintain-immortalwrt-fork/scripts/verify-single-patch.sh
```

Stop if the working tree is dirty or the single-`FIX` invariant fails. Resolve that first with the maintain skill.

2. Confirm the base tag and current commit:

```bash
git describe --tags --abbrev=0 --exclude='my/*' --exclude='backup/*' HEAD
git rev-parse --short HEAD
git log --oneline --decorate -1
```

The base tag should be the upstream release tag intended for this build. Excluding `my/*` and `backup/*` prevents a previous personal build tag or safety tag from becoming the next base name.

3. Create the personal build tag with the existing script:

```bash
.agents/skills/maintain-immortalwrt-fork/scripts/tag-build.sh <suffix>
```

Use `-p` only when the user explicitly wants the tag pushed immediately:

```bash
.agents/skills/maintain-immortalwrt-fork/scripts/tag-build.sh <suffix> -p
```

4. Verify the tag:

```bash
git show --no-patch --decorate --pretty=fuller my/<base-tag>-<suffix>
git rev-parse my/<base-tag>-<suffix>^{}
git rev-parse HEAD
```

The peeled tag commit (`^{}`) must match `HEAD`, and `HEAD` must be the `FIX` commit verified in step 1.

5. Check out the build tag when the user wants to build from the anchored source:

```bash
git checkout my/<base-tag>-<suffix>
git status --short --branch
git log --oneline --decorate -1
```

`HEAD (no branch)` / detached HEAD is expected here. Do not make fork maintenance
changes while detached; switch back to the branch first:

```bash
git switch <current-branch>
```

6. If not pushed during creation, provide the exact push command:

```bash
git push origin my/<base-tag>-<suffix>
```

## Common Requests

- "基于当前上游 tag 打一个我们的 tag" means run the workflow above with the next available suffix.
- "tag+fix" means the personal tag should point to the local `FIX` commit, not to the upstream tag commit.
- "checkout 出来" means check out the just-created `my/*` tag for building; detached HEAD is expected.
- "可以推上去" means rerun or create with `-p`, or push the already-created `my/*` tag to `origin`.
