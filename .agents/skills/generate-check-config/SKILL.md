---
name: generate-check-config
description: >-
  从本仓库当前 .config 生成带中文注释、按功能整理的 check.config，
  或在 menuconfig 修改后刷新并验证清单。自动依赖交给 defconfig；
  只保留影响还原结果的禁用项。不用于编译固件或修改在线路由器。
---

# 生成个人配置清单

以当前 `.config` 为事实源，输出唯一维护的精简清单 `check.config`。
默认关闭且用户也未选择的功能无需列出；需要覆盖默认值的禁用项必须保留。
例如不需要为默认关闭的 BanIP 写禁用声明，但删除默认网卡驱动、关闭默认镜像格式的选择不能省略。

从仓库根目录运行：

```bash
python3 .agents/skills/generate-check-config/scripts/generate.py
```

脚本在仓库外备份输入和已有输出，用本地 Kconfig、当前 feeds 和严格循环依赖检查生成并核对清单。
它以包选择关系压缩候选，再实际展开比较全部有效配置值；只有等价才写入输出。
生成和 `--verify` 均先运行本仓库 `prepare-tmpinfo` 扫描并重建 `tmp/.config-*.in`，
更新本地 `conf` 后再展开，避免旧缓存造成错误的等价结论。刷新日志保存在备份目录。
不会改写 `.config`、更新 feeds 源码版本或创建 Git 提交；会刷新临时元数据及构建工具。
若当前 `.config` 在新元数据下展开不一致，报告差异并停止，不写输出；不要擅自覆盖用户的新选择。

输出头部记录 UTC 时间及 `source-provenance` JSON：原始 `.config` SHA-256、主仓库提交、
各 feed 提交与已跟踪改动摘要、生成元数据摘要。此记录用于追溯，不是 feeds 锁定或完整构建复现保证；
不包含未跟踪文件。`--verify` 对缺失或变化的来源记录给出提示，最终以当前 Kconfig 的等价比较为准。
主仓库的 `check.config` 排除在改动摘要之外，避免输出引用自身；amend FIX 后提交号变化属于正常提示。

生成后检查中文分组与独立能力说明。配置不保存用户操作历史，不能把图推导出的入口宣称为用户曾手动勾选。
没有上层使用者的库也可能是独立选中的兼容能力；保留并说明，除非用户授权删除。
用户取消某个应用后，其仍启用的运行库应按当前配置保留，不替用户顺便删除。

需要手动调整分组、注释或继续精简时，修改 `check.config` 后运行：

```bash
python3 .agents/skills/generate-check-config/scripts/generate.py --verify check.config
```

报告启用功能变化、有效条目数量、必要禁用项数量和等价验证结果。
生成结果描述当前主仓库、feeds 和默认值组合；跨版本需重新生成验证，不保证未来默认值不变。
只在用户要求应用清单时用它重建 `.config`：

```bash
cp check.config .config
make defconfig RECURSIVE_DEP_IS_ERROR=1
```

遵循仓库单个 `FIX` 约定，用 `maintain-immortalwrt-fork` 的 amend 脚本纳入变更；不要另建提交或自行推送。

维护脚本后运行隔离回归测试（使用本仓库已构建的 `conf`）：

```bash
python3 .agents/skills/generate-check-config/scripts/test_generate.py
```

测试在仓库外构造最小 Kconfig，覆盖缓存过期、索引缺失、来源记录与不等价清单拒绝；
仍需在真实仓库运行一次生成和 `--verify`，检查 `.config` 字节未变。
