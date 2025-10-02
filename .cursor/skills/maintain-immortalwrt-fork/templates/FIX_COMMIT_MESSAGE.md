# FIX Commit Message Template

The fork keeps **exactly one** commit on top of upstream. Its message body
serves as the changelog for every personal change. The `scripts/amend-fix.sh -m`
flag maintains this format automatically — you rarely need to edit by hand.

## Subject

Always:

```
FIX
```

## Body (recommended format)

```
FIX

Personal patches and configuration on top of upstream.

Changelog:
- [config] enable LuCI HTTPS by default
- [pkg] add xray-core to default image
- [fix] workaround 6GHz null deref (drop when upstream PR #5678 lands)
- [tooling] add .cursor/skills/maintain-immortalwrt-fork and AGENTS.md
```

## Changelog tags

| Tag        | Use for                                             |
|------------|-----------------------------------------------------|
| `[config]` | Default `.config`, feeds.conf, build defaults       |
| `[feat]`   | New features / capabilities                         |
| `[fix]`    | Workarounds for upstream bugs (note expected drop)  |
| `[pkg]`    | Adding / removing / modifying packages              |
| `[tune]`   | Performance / size tuning                           |
| `[tooling]`| Meta: scripts, AGENTS.md, this skill, docs          |

## Editing by hand

```bash
.cursor/skills/maintain-immortalwrt-fork/scripts/amend-fix.sh --reword
```

Opens the editor with the existing message. Add or rewrite lines under
`Changelog:` and save.
