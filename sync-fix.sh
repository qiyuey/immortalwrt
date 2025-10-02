#!/usr/bin/env bash
set -e

echo "🧭 ImmortalWrt Fix Tagger"
echo "--------------------------------"

# 1️⃣ 记录当前所在分支
ORIGINAL_BRANCH=$(git branch --show-current)

# 2️⃣ 自动检测最新官方 tag
REMOTE_NAME="upstream"
if ! git remote get-url $REMOTE_NAME >/dev/null 2>&1; then
  REMOTE_NAME="origin"
fi

echo "🔍 正在从远程 [$REMOTE_NAME] 获取最新 tag..."
git fetch --tags $REMOTE_NAME >/dev/null 2>&1
LATEST_TAG=$(git tag -l --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)

if [[ -z "$LATEST_TAG" ]]; then
  echo "❌ 未检测到任何官方 tag，请检查仓库。"
  exit 1
fi

echo "✅ 检测到最新官方 Tag: $LATEST_TAG"
read -p "👉 是否使用此 tag ($LATEST_TAG)? [Y/n 或输入自定义 tag]: " INPUT_TAG

if [[ -z "$INPUT_TAG" || "$INPUT_TAG" =~ ^[Yy]$ ]]; then
  BASE_TAG="$LATEST_TAG"
else
  BASE_TAG="$INPUT_TAG"
fi

if ! git rev-parse "refs/tags/$BASE_TAG" >/dev/null 2>&1; then
  echo "❌ 未找到指定的 Tag: $BASE_TAG"
  exit 1
fi

echo "🧩 将基于官方 tag：$BASE_TAG"

# 3️⃣ 获取当前分支最新 commit 作为 FIX
FIX_COMMIT=$(git rev-parse HEAD)
FIX_MSG=$(git log -1 --pretty=format:"%s")

echo
echo "🔍 当前 FIX commit:"
echo "   $FIX_COMMIT - $FIX_MSG"
echo

# 4️⃣ 创建临时分支
TMP_BRANCH="tmp-fix-${BASE_TAG}"
echo "🌀 创建临时分支: $TMP_BRANCH"
git checkout -B "$TMP_BRANCH" "$BASE_TAG"

# 5️⃣ 应用 FIX commit
echo "🔧 正在应用 FIX commit..."
if ! git cherry-pick "$FIX_COMMIT"; then
  echo "⚠️ 发生冲突，请手动解决后执行："
  echo "   git cherry-pick --continue"
  exit 1
fi

# 6️⃣ 创建新的 fix tag
FIX_TAG="${BASE_TAG}-fix"
echo "🏷️ 创建新 Tag: $FIX_TAG"
git tag -a "$FIX_TAG" -m "Auto-generated fix based on $BASE_TAG"

# 7️⃣ 推送 Tag
echo
read -p "🚀 是否推送新 Tag 到远程仓库 (origin)? (y/n): " PUSH_CONFIRM
if [[ "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
  git push origin "$FIX_TAG"
  echo "✅ 已推送到远程: origin/$FIX_TAG"
else
  echo "ℹ️ 已在本地创建 Tag，可手动推送："
  echo "   git push origin $FIX_TAG"
fi

# 8️⃣ 删除临时分支，并切换到 tag 状态
echo
echo "🧹 清理临时分支..."
git checkout "$FIX_TAG"
git branch -D "$TMP_BRANCH" >/dev/null 2>&1 || true

echo
echo "✅ 当前处于 tag [$FIX_TAG] (detached HEAD 状态)"
echo "🎉 完成！新 Tag：$FIX_TAG"
