#!/usr/bin/env bash

# 只检查构建机需要直接执行的脚本；不扫描、不改写业务源码。

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
required_lf_files=(
    "$ROOT_DIR/scripts/build_offline_deps.sh"
    "$ROOT_DIR/scripts/verify_text_eol.sh"
)

bad_count=0
for file_path in "${required_lf_files[@]}"; do
    if [[ ! -f "$file_path" ]]; then
        printf '构建脚本不存在：%s\n' "$file_path" >&2
        bad_count=$((bad_count + 1))
        continue
    fi

    if LC_ALL=C grep -q $'\r' "$file_path"; then
        printf '构建脚本包含 CRLF：%s\n' "$file_path" >&2
        bad_count=$((bad_count + 1))
    fi
done

if [[ "$bad_count" -ne 0 ]]; then
    printf '检测到 %d 个构建脚本格式问题；只修复上述文件。\n' "$bad_count" >&2
    exit 1
fi

echo "构建脚本格式检查通过。"
