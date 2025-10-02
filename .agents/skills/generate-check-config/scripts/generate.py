#!/usr/bin/env python3
"""Generate a commented feature seed and prove Kconfig equivalence."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[4]
ENV = {**os.environ, "TOPDIR": str(ROOT)}


def parse(text):
    result = {}
    for line in text.splitlines():
        if line.startswith("CONFIG_") and "=" in line:
            key, value = line.split("=", 1)
            result[key] = value
        elif line.startswith("# CONFIG_") and line.endswith(" is not set"):
            result[line[2:-11]] = "n"
    return result


def render(key, value):
    return f"# {key} is not set" if value == "n" else f"{key}={value}"


def difference(expected, actual):
    return {key: (expected.get(key, "n"), actual.get(key, "n"))
            for key in sorted(expected.keys() | actual.keys())
            if expected.get(key, "n") != actual.get(key, "n")}


def run(args, log_path=None):
    proc = subprocess.run(args, cwd=ROOT, env=ENV, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if log_path is not None:
        log_path.write_text(proc.stdout)
    if proc.returncode:
        raise RuntimeError(f"{' '.join(map(str, args))}\n{proc.stdout[-5000:]}")
    return proc.stdout


METADATA = ("tmp/.config-package.in", "tmp/.config-target.in", "tmp/.config-feeds.in")
PROVENANCE_PREFIX = "# source-provenance: "


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def git_state(path):
    # Only feed checkouts with their own .git are inspected by the caller.
    commit = run(["git", "-C", str(path), "rev-parse", "HEAD"]).strip()
    diff = run(["git", "-C", str(path), "diff", "--binary", "HEAD", "--", ".",
                ":(exclude)check.config"])
    return {"commit": commit, "tracked_diff_sha256": sha256(diff.encode())}


def provenance(snapshot):
    return {
        "config_sha256": sha256(snapshot),
        "source": git_state(ROOT),
        "feeds": {p.name: git_state(p) for p in sorted((ROOT / "feeds").iterdir())
                  if not p.is_symlink() and (p / ".git").exists()},
        "metadata": {name: sha256((ROOT / name).read_bytes()) for name in METADATA},
    }


def refresh_metadata(backup):
    # These are generated indexes, never source files. Rebuild them even if a
    # stale/corrupt cache has a newer timestamp than the package information.
    for name in METADATA:
        (ROOT / name).unlink(missing_ok=True)
    run(["make", "-s", "prepare-tmpinfo", "scan_unchanged=false"],
        backup / "refresh-metadata.log")
    run(["make", "-s", "scripts/config/conf"], backup / "build-conf.log")
    for name in METADATA:
        if not (ROOT / name).is_file():
            raise RuntimeError(f"Metadata refresh did not produce {name}; see {backup}")


def category(key, value):
    name = key.removeprefix("CONFIG_PACKAGE_")
    if value == "n":
        return "覆盖上游默认值的禁用项（省略会改变当前配置）"
    if key.startswith("CONFIG_TARGET_") or key == "CONFIG_GRUB_IMAGES":
        return "目标平台、镜像与分区参数"
    if key.startswith(("CONFIG_DEVEL", "CONFIG_CCACHE", "CONFIG_TOOLCHAIN", "CONFIG_GCC", "CONFIG_LUCI_SRCDIET")):
        return "构建方式与源码压缩"
    if key.startswith("CONFIG_BUSYBOX_"):
        return "BusyBox 工具选项"
    if key.startswith("CONFIG_KERNEL_"):
        return "内核功能（按当前选择保留）"
    if name.startswith("default-settings") or key.startswith("CONFIG_LUCI_LANG_"):
        return "地区与语言默认设置"
    if name.startswith(("luci-ssl", "luci-theme", "luci-app-uhttpd", "rpcd", "ttyd")):
        return "Web 管理、主题与后端接口"
    if name.startswith("luci-app-diskman") or name in ("f2fs-tools", "mount-utils", "btrfs-progs", "parted", "smartmontools"):
        return "磁盘管理与文件系统工具"
    if name.startswith("luci-") or name in ("wakeonlan", "etherwake"):
        return "网络应用与协议界面（基础页面和翻译由依赖生成）"
    if name.startswith(("containerd", "runc", "tini", "kmod-veth", "kmod-dummy")):
        return "容器工具与虚拟网络"
    if name.startswith(("iptables", "ip6tables", "xtables", "kmod-ipt", "kmod-ipsec", "kmod-nf", "kmod-tun")):
        return "防火墙、隧道与网络兼容功能"
    if name.startswith("kmod-") or name.endswith("-microcode"):
        return "硬件支持与其他内核模块"
    if name.startswith(("nginx",)) or key.startswith("CONFIG_NGINX_"):
        return "Nginx HTTPS 服务与模块选项"
    if name.startswith(("lib", "ucode-")):
        return "仍需显式保留的独立库与接口能力"
    if name in ("ca-certificates", "iperf3", "tcping", "curl", "wget-ssl", "openssl-util"):
        return "网络排障、下载与证书工具"
    return "其他独立工具和功能选项"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="check.config")
    parser.add_argument("--verify", metavar="SEED", help="Only verify an existing seed")
    args = parser.parse_args()
    source = ROOT / ".config"
    snapshot = source.read_bytes()
    backup_root = Path.home() / "immortalwrt-build-backups"
    backup_root.mkdir(exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix="check-config-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S") + "-", dir=backup_root))
    (backup / "source.config").write_bytes(snapshot)
    print(f"Backup: {backup}", flush=True)
    refresh_metadata(backup)
    if source.read_bytes() != snapshot:
        raise RuntimeError(".config changed while refreshing metadata; output not written")
    context = provenance(snapshot)

    def expand(values):
        seed = backup / "candidate.seed"
        output = backup / "expanded.config"
        seed.write_text("".join(render(k, v) + "\n" for k, v in values.items()))
        log = run(["scripts/config/conf", "--fatalrecursive", "--defconfig=" + str(seed), "-w", str(output), "Config.in"])
        (backup / "last-expand.log").write_text(log)
        return parse(output.read_text())

    reference = parse(snapshot.decode())
    normalized = expand(reference)
    delta = difference(reference, normalized)
    if delta:
        raise RuntimeError(f"Current .config needs normalization after metadata refresh; .config and output not written. First differences: {list(delta.items())[:12]}")
    if args.verify:
        path = (ROOT / args.verify).resolve()
        seed_text = path.read_text()
        recorded = next((json.loads(line[len(PROVENANCE_PREFIX):])
                         for line in seed_text.splitlines()
                         if line.startswith(PROVENANCE_PREFIX)), None)
        if recorded is None:
            print("Notice: seed has no recorded provenance; checking against current sources.")
        elif recorded != context:
            changed = [key for key in context if recorded.get(key) != context[key]]
            print("Notice: provenance changed (" + ", ".join(changed) + "); checking current Kconfig equivalence.")
        delta = difference(reference, expand(parse(seed_text)))
        if delta:
            raise RuntimeError(f"Seed differs from .config: {list(delta.items())[:20]}")
        if source.read_bytes() != snapshot:
            raise RuntimeError(".config changed during verification")
        if provenance(snapshot) != context:
            raise RuntimeError("Source/feed/metadata context changed during verification; retry")
        print(f"Verified all {len(reference)} configuration values; .config unchanged.")
        return

    output = (ROOT / args.output).resolve()
    if output == source.resolve():
        raise RuntimeError("Output must not overwrite .config")
    previous_output = output.read_bytes() if output.exists() else None
    if previous_output is not None:
        (backup / "previous-check.config").write_bytes(previous_output)
    raw_text = run(["sh", "scripts/diffconfig.sh"])
    (backup / "native-diff.config").write_text(raw_text)
    raw = parse(raw_text)
    if difference(reference, expand(raw)):
        raise RuntimeError("Native diff cannot reproduce source; inspect saved native-diff.config")

    # A select edge only nominates redundant entries. Real expansion below is
    # authoritative, including conditional selects, defaults and tristates.
    graph = {}
    parent = None
    for line in (ROOT / "tmp/.config-package.in").read_text().splitlines():
        match = re.match(r"\s*(?:menu)?config\s+(\S+)", line)
        if match:
            parent = "CONFIG_" + match[1]
        match = re.match(r"\s*select\s+(PACKAGE_\S+)", line)
        if match and parent:
            child = "CONFIG_" + match[1]
            if reference.get(parent) == reference.get(child) == "y":
                graph.setdefault(parent, set()).add(child)

    def reachable(key):
        visited, todo = set(), list(graph.get(key, ()))
        while todo:
            node = todo.pop()
            if node in visited:
                continue
            visited.add(node)
            todo.extend(graph.get(node, ()))
        return visited

    roots = {k for k, v in raw.items() if k.startswith("CONFIG_PACKAGE_") and v == "y"}
    for key in sorted(roots.copy()):
        if key in roots and any(key in reachable(other) for other in roots if other != key):
            roots.remove(key)
    protected = ("CONFIG_TARGET_", "CONFIG_DEVEL", "CONFIG_BUSYBOX_CUSTOM", "CONFIG_CCACHE", "CONFIG_TOOLCHAINOPTS")
    candidate = {k: v for k, v in raw.items()
                 if v == "n" or k.startswith(protected)
                 or (k in roots and not k.startswith("CONFIG_PACKAGE_luci-i18n-"))
                 or v == "m"}
    recovered = set()
    for _ in range(4):
        delta = difference(reference, expand(candidate))
        if not delta:
            break
        for key in delta:
            candidate[key] = reference.get(key, "n")
            recovered.add(key)
    else:
        raise RuntimeError("Candidate cannot reproduce source after recovery; output not written")
    for key in sorted(recovered):
        trial = {k: v for k, v in candidate.items() if k != key}
        if not difference(reference, expand(trial)):
            candidate = trial
    # Default-off negatives, e.g. removed applications, are not emitted by the
    # native exporter. Recovered negatives are checked as well before retention.
    for key in sorted(k for k in recovered if candidate.get(k) == "n"):
        trial = {k: v for k, v in candidate.items() if k != key}
        if not difference(reference, expand(trial)):
            candidate = trial
    if difference(reference, expand(candidate)):
        raise RuntimeError("Final equivalence check failed")
    groups = {}
    for key, value in candidate.items():
        groups.setdefault(category(key, value), []).append(render(key, value))
    header = (
        "# 个人固件功能清单（从当前 .config 整理，中文注释）\n"
        "# 保留功能入口、独立能力及必要的默认值覆盖；自动依赖交给 defconfig。\n"
        "# 默认已关闭的项目不列出；禁用项只用于保留与默认值不同的选择。\n"
        "# 使用：cp check.config .config && make defconfig RECURSIVE_DEP_IS_ERROR=1\n"
        "# 本清单已按当前主仓库、feeds 和 Kconfig 验证；跨版本需重新核对。\n"
    )
    header += "# generated-at-utc: " + datetime.datetime.now(datetime.timezone.utc).isoformat() + "\n"
    header += PROVENANCE_PREFIX + json.dumps(context, ensure_ascii=False, sort_keys=True) + "\n"
    content = header + "".join("\n# " + title + "\n" + "\n".join(entries) + "\n" for title, entries in groups.items())
    if source.read_bytes() != snapshot:
        raise RuntimeError(".config changed during generation; output not written")
    actual_output = output.read_bytes() if output.exists() else None
    if actual_output != previous_output:
        raise RuntimeError("Output changed during generation; refusing to overwrite concurrent edits")
    if provenance(snapshot) != context:
        raise RuntimeError("Source/feed/metadata context changed during generation; output not written")
    output.write_text(content)
    print(f"Generated {output}: {len(raw)} -> {len(candidate)} directives, {sum(v == 'n' for v in candidate.values())} necessary disables.")
    print(f"Verified all {len(reference)} configuration values; .config unchanged.")
    print(f"Backup: {backup}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError) as error:
        raise SystemExit(str(error))
