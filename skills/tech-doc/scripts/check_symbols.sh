#!/usr/bin/env bash
# 符号巡检：从文档中提取 `符号/路径/哈希` 引用，到指定仓库核对是否存在。
# - 普通符号 → grep 仓库内容
# - 路径型引用（含 / 或带扩展名）→ 文件存在性检查（别名前缀探测 + find 后缀匹配）
# - 7~40 位纯十六进制 → git rev-parse 校验（commit 哈希）
# Advisory 工具：NOT FOUND 不一定是错（概念词/示例值/仓库外引用），由调用方逐条判断。
#
# 用法: check_symbols.sh <文档路径> <仓库根>
# 依赖: bash / grep / sed / find / git（Windows 用 Git Bash）
# 可移植性：grep 统一用 --binary-files=without-match 替代 -I（BSD/GNU 皆支持）

set -uo pipefail

doc="${1:-}"
repo="${2:-.}"

[ -n "$doc" ] && [ -f "$doc" ] || { echo "用法: $0 <文档路径> <仓库根>（文档不存在: $doc）" >&2; exit 2; }
[ -d "$repo" ] || { echo "仓库根不存在: $repo" >&2; exit 2; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# 先剥离 fenced code block：代码片段是引用源，不是待核对对象
sed '/^[[:space:]]*```/,/^[[:space:]]*```/d' "$doc" > "$tmp"

# 路径别名前缀探测（仓库使用 apps/ rmc/ srcs/ 等别名）
prefixes=("" "src/" "src/apps/" "src/apps/Quotation/" "src/apps/SDK/" "srcs/")

path_exists() {
  local token="$1" p f base found
  for p in "${prefixes[@]}"; do
    [ -e "$repo/$p$token" ] && return 0
  done
  base="${token##*/}"
  found="$(find "$repo" \( -path '*/node_modules' -o -path '*/.git' \
           -o -path '*/dist' -o -path '*/build' \) -prune -o \
           -type f -name "$base" -print 2>/dev/null | head -10)"
  [ -z "$found" ] && return 1
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in *"$token") return 0 ;; esac
  done <<< "$found"
  return 1
}

grep -oE '`[^`]+`' "$tmp" | sed 's/^`//; s/`$//; s:/*$::' | sort -u | while IFS= read -r token; do
  case "$token" in *" "*) continue ;; esac
  [ "${#token}" -ge 3 ] || continue
  if printf '%s' "$token" | LC_ALL=C grep -q '[^ -~]'; then continue; fi
  case "$token" in /*) continue ;; esac   # 以 / 开头视为 URL/route，交给内容 grep

  ok=0
  case "$token" in
    *[!0-9a-f]*) ;;                                      # 含非十六进制字符
    *)  [ "${#token}" -ge 7 ] && git -C "$repo" rev-parse --verify --quiet "${token}^{commit}" >/dev/null 2>&1 && ok=1 ;;
  esac

  if [ "$ok" -eq 0 ]; then
    case "$token" in
      */*|*.ts|*.tsx|*.js|*.jsx|*.json|*.md|*.sh|*.scss|*.css|*.proto)
        path_exists "$token" && ok=1 ;;
      *) ;;
    esac
  fi

  if [ "$ok" -eq 0 ]; then
    n="$(grep -rnF --binary-files=without-match --exclude-dir=.git \
          --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
          -- "$token" "$repo" 2>/dev/null | wc -l)"
    [ "$n" -eq 0 ] && echo "NOT FOUND: $token"
  fi
done

echo "---"
echo "巡检完成。NOT FOUND 逐条判断：概念词/示例值/仓库外引用可忽略；"
echo "真实符号名或路径则修正文档（或确认代码已重命名，文档过期）。"
