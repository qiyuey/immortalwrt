#!/bin/bash
set -e

echo "🧭 ImmortalWrt Fix Tagger"
echo "--------------------------------"

# 1️⃣ 获取最新官方 tag
echo "🔍 正在从远程 [upstream] 获取最新 tag..."
git fetch upstream --tags -q

# 直接从 upstream 解析最新 tag（去掉 ^{}）
LATEST_TAG=$(git ls-remote --tags upstream | grep -o 'refs/tags/v[0-9][^{}]*' | grep -v '\^' | sed 's|refs/tags/||' | sort -V | tail -n1)

if [ -z "$LATEST_TAG" ]; then
    echo "❌ 未能从 upstream 获取 tag，请检查远程设置："
    echo "   👉 执行命令：git remote -v"
    exit 1
fi

# 2️⃣ 用户确认或输入自定义 tag
read -r -p "✅ 检测到最新官方 tag: ${LATEST_TAG}
👉 是否使用此 tag？（直接回车使用 ${LATEST_TAG}，或输入自定义 tag 名，例如 v24.10.2）: " INPUT_TAG

if [ -z "$INPUT_TAG" ]; then
    TARGET_TAG="$LATEST_TAG"
else
    TARGET_TAG="$INPUT_TAG"
fi
echo "🧩 将基于官方 tag：${TARGET_TAG}"
echo ""

# 3️⃣ 检测 Fix commit
echo "🔎 正在检测 fix commit..."
FIX_COMMIT=$(git log -1 --grep="fix" --grep="FIX" --format="%H")

if [ -z "$FIX_COMMIT" ]; then
    echo "❌ 未找到包含 'fix' 的提交，请确保当前分支上有你的修复提交。"
    exit 1
fi

FIX_MSG=$(git log -1 --format="%s" "$FIX_COMMIT")
echo "✅ 检测到 fix commit:"
echo "   ${FIX_COMMIT} - ${FIX_MSG}"
echo ""

# 4️⃣ 检查目标 fix tag 是否已存在
FIX_TAG="${TARGET_TAG}-fix"

if git rev-parse "$FIX_TAG" >/dev/null 2>&1; then
    echo "⚠️ 本地已存在 tag: ${FIX_TAG}"
    read -r -p "是否覆盖此 tag？(y/n): " OVERWRITE
    if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
        echo "⏹ 已取消操作。"
        exit 0
    fi
    git tag -d "$FIX_TAG" >/dev/null 2>&1 || true
    echo "🗑️ 已删除本地旧 tag：${FIX_TAG}"
fi

# 5️⃣ 检查远程是否存在同名 tag
if git ls-remote --tags origin | grep -q "refs/tags/${FIX_TAG}$"; then
    echo "⚠️ 远程已存在 tag: ${FIX_TAG}"
    read -r -p "是否删除远程同名 tag 并重新推送？(y/n): " DEL_REMOTE
    if [[ "$DEL_REMOTE" == "y" || "$DEL_REMOTE" == "Y" ]]; then
        git push origin --delete "refs/tags/${FIX_TAG}" || true
        echo "🗑️ 已删除远程旧 tag：${FIX_TAG}"
    else
        echo "⏹ 已取消操作。"
        exit 0
    fi
fi

# 6️⃣ 创建临时分支并应用 fix
TMP_BRANCH="tmp-fix-${TARGET_TAG}"

# 如果临时分支已存在，则删除
if git show-ref --verify --quiet "refs/heads/${TMP_BRANCH}"; then
    echo "🧹 检测到残留临时分支 ${TMP_BRANCH}，正在删除..."
    git branch -D "${TMP_BRANCH}" >/dev/null 2>&1 || true
fi

echo "🌀 创建临时分支: ${TMP_BRANCH}"
git checkout -b "${TMP_BRANCH}" "${TARGET_TAG}" >/dev/null

echo "🔧 正在应用 fix commit..."
git cherry-pick "${FIX_COMMIT}" || {
    echo "⚠️ cherry-pick 过程中发生冲突，请手动解决后执行：git cherry-pick --continue"
    exit 1
}

# 7️⃣ 创建新的 -fix tag（防止残留）
echo "🏷️ 创建新 tag: ${FIX_TAG}"

if git show-ref --tags "${FIX_TAG}" >/dev/null 2>&1; then
    echo "🧹 检测到残留 tag：${FIX_TAG}，正在清理..."
    git tag -d "${FIX_TAG}" >/dev/null 2>&1 || true
fi

git tag -a "${FIX_TAG}" -m "${FIX_MSG}"
git show-ref "${FIX_TAG}" | tail -n 1
echo ""

# 8️⃣ 推送 tag 到远程
read -r -p "🚀 是否推送新 tag 到远程仓库 (origin)? (y/n): " PUSH_CONFIRM
if [[ "$PUSH_CONFIRM" == "y" || "$PUSH_CONFIRM" == "Y" ]]; then
    git push origin "${FIX_TAG}"
    echo "✅ 已推送到远程: origin/${FIX_TAG}"
else
    echo "⏩ 已跳过推送。"
fi

# 9️⃣ 删除临时分支并切换到 tag 状态
echo ""
echo "🧹 清理临时分支..."
git checkout "${FIX_TAG}" >/dev/null
git branch -D "${TMP_BRANCH}" >/dev/null
echo "✅ 已切换到 tag 状态: ${FIX_TAG}"

echo ""
echo "🎉 完成！新 tag：${FIX_TAG}"
