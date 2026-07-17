set -eu

cd "$(dirname "$0")"

git add -A

if git diff --cached --quiet; then
    echo "没有变化"
    exit 0
fi

git commit -m "sync"
git push

echo "同步完成"
