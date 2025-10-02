---
name: annotate-check-config
description: 为已有 check.config 补充或修正中文说明注释，解释配置项用途、必要禁用项及相关取舍，保持配置值不变。不用于生成清单、选择软件包或编译固件；生成清单直接运行 scripts/checkconfig.sh。
---

# 为配置清单添加说明

以现有 `check.config` 为编辑对象，保留全部配置键和值。`# CONFIG_… is not set`
是禁用配置项，不能当作普通注释删除。没有清单时先说明需要生成，不擅自用当前 `.config` 替换清单。

按实际需要读取对应包的 Makefile、Config.in 和目标平台配置，解释功能用途及启用或禁用的效果。
优先补充影响镜像格式、硬件支持、服务能力或依赖关系的说明；相关条目可共用一段注释。
区分已验证的效果与需要用户确认的使用意图，不把配置选择解释成用户的历史决策。
避免为每个显而易见的选项重复名称，也不要把当前配置推荐为所有设备的默认配置。

只改普通注释与分组，不增删配置项、不改变值、不改写 `.config`。
保留 `generated-at-utc`、`source-provenance` 记录；添加注释不代表重新生成或验证了原始来源。
生成脚本会重建基础分组，手工补充的说明在重新生成时不会自动保留。

编辑前后用 `scripts/checkconfig.py` 的 `parse()` 比较配置映射，确认完全一致。
若任务还要求核对清单能否还原当前 `.config`，另行运行：

```bash
python3 scripts/checkconfig.py --verify check.config
```

验证不等价时报告差异，不通过修改配置值来让注释任务通过。
按照仓库维护技能将注释变更合入唯一 `FIX`，不自行推送。

生成配置是独立于此技能的脚本操作，无需 LLM：

```bash
./scripts/checkconfig.sh > check.config
```

标准输出仅含通过验证的清单，诊断在标准错误。`>` 会提前清空目标；
需要保留旧清单直到生成成功时使用 `python3 scripts/checkconfig.py`。
生成器回归测试入口为 `python3 scripts/tests/test_checkconfig.py`。
