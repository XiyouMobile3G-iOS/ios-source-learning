#!/bin/bash
#
# tests/maps-integrity.test.sh —— 地图入口、路由和版本清单的静态完整性检查
#
# 不下载上游源码；在没有 bootstrap 工作区的干净 clone 中也必须可运行。
#
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILS=0

ok() {
  printf '  ok  %s\n' "$1"
}
fail() {
  printf '  FAIL %s\n' "$1"
  FAILS=$((FAILS + 1))
}

assert_file() {
  if [ -f "$1" ]; then
    ok "$2"
  else
    fail "$2: missing $1"
  fi
}

assert_eq() {
  if [ "$1" = "$2" ]; then
    ok "$3"
  else
    fail "$3: got '$1', want '$2'"
  fi
}

printf '地图文件配对与长度\n'
map_count=0
while IFS= read -r map; do
  map_count=$((map_count + 1))
  relative="${map#maps/}"
  directory="${relative%/AGENTS.md}"
  pointer="$ROOT/maps/$directory/CLAUDE.md"
  lines="$(wc -l < "$ROOT/$map" | tr -d ' ')"

  if [ "$lines" -le 200 ]; then
    ok "$map 不超过 200 行"
  else
    fail "$map 超过 200 行: $lines"
  fi

  if [ -f "$pointer" ]; then
    ok "$directory 有 CLAUDE.md 入口"
  else
    fail "$directory 缺少 CLAUDE.md 入口"
  fi

  pointer_lines="$(wc -l < "$pointer" | tr -d ' ')"
  assert_eq "$pointer_lines" "3" "$directory/CLAUDE.md 保持三行指针"

  if grep -q 'AGENTS.md' "$pointer"; then
    ok "$directory/CLAUDE.md 指向 AGENTS.md"
  else
    fail "$directory/CLAUDE.md 没有指向 AGENTS.md"
  fi
  map_links_ok=1
  links="$(
    grep -Eo '\]\((\./|\.\./)[^)]*AGENTS\.md(#[^)]*)?\)' "$ROOT/$map" 2>/dev/null \
      | sed -E 's/^\]\(//; s/\)$//; s/#.*$//' \
      || true
  )"
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    target_dir="$(dirname "$ROOT/$map")/$(dirname "$target")"
    if [ ! -d "$target_dir" ]; then
      fail "$map 的地图链接目录不存在: $target"
      map_links_ok=0
      continue
    fi
    target_path="$(cd "$target_dir" && pwd)/$(basename "$target")"
    case "$target_path" in
      "$ROOT"/maps/*) ;;
      *)
        fail "$map 的地图链接越出 maps/: $target"
        map_links_ok=0
        continue
        ;;
    esac
    tracked_path="${target_path#"$ROOT"/}"
    if ! git -C "$ROOT" ls-files --error-unmatch "$tracked_path" >/dev/null 2>&1; then
      fail "$map 的地图链接目标未受版本控制: $target"
      map_links_ok=0
    fi
  done <<EOF
$links
EOF
  if [ "$map_links_ok" -eq 1 ]; then
    ok "$map 内部地图链接有效"
  fi

done <<EOF
$(git -C "$ROOT" ls-files 'maps/**/AGENTS.md')
EOF
claude_count="$(git -C "$ROOT" ls-files 'maps/**/CLAUDE.md' | wc -l | tr -d ' ')"
assert_eq "$map_count" "$claude_count" "每份地图正文都有对应入口"


printf '\n教学提示词路由\n'
assert_file "$ROOT/prompts/teaching/INDEX.md" '教学提示词索引存在'
assert_file "$ROOT/prompts/teaching/methods/progressive-dialogue.md" '默认教学方法存在'
assert_file "$ROOT/prompts/teaching/methods/problem-first-design.md" '可选教学方法存在'
assert_file "$ROOT/prompts/teaching/styles/interview-answer.md" '默认表达风格存在'

printf '\n源码清单路由\n'
# 这些映射把 sources.sh 的下载目标与地图根目录绑定，避免新增源码后忘记地图。
source "$ROOT/sources.sh"
for spec in "${SOURCES[@]}"; do
  IFS='|' read -r key directory _ _ _ _ _ _ <<EOF
$spec
EOF
  case "$key" in
    objc4) map_root='maps/new objc4' ;;
    cf) map_root='maps/CF-1153.18-apple' ;;
    libdispatch-apple) map_root='maps/libdispatch-apple' ;;
    libdispatch) map_root='maps/libdispatch' ;;
    foundation) map_root='maps/swift-corelibs-foundation' ;;
    swift-foundation) map_root='maps/swift-foundation' ;;
    gnustep) map_root='maps/gnustep-base' ;;
    afnetworking) map_root='maps/third-party/AFNetworking' ;;
    jsonmodel) map_root='maps/third-party/JSONModel' ;;
    yymodel) map_root='maps/third-party/YYModel' ;;
    sdwebimage) map_root='maps/third-party/SDWebImage' ;;
    *) fail "sources.sh 存在未映射目标: $key"; continue ;;
  esac
  if [ -f "$ROOT/$map_root/AGENTS.md" ]; then
    ok "$key 有对应地图根目录"
  else
    fail "$key 缺少对应地图根目录: $map_root"
  fi
done

if [ "$FAILS" -ne 0 ]; then
  printf '\n%d 项失败\n' "$FAILS"
  exit 1
fi
printf '\n全部通过\n'
