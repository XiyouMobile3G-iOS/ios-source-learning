#!/bin/bash
#
# tests/prompts-integrity.test.sh —— 教学提示词索引与协议的静态完整性检查
#
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INDEX="$ROOT/prompts/teaching/INDEX.md"
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
assert_count() {
  local got
  got="$(grep -F -c "$1" "$INDEX" || true)"
  if [ "$got" = "$2" ]; then
    ok "$3"
  else
    fail "$3: got $got, want $2"
  fi
}
assert_contains() {
  if grep -Fq "$2" "$1"; then
    ok "$3"
  else
    fail "$3: missing '$2' in $1"
  fi
}

printf '提示词索引\n'
assert_file "$INDEX" '索引存在'
assert_count '| 默认 | 渐进式互动讲解 |' 1 '默认教学方法唯一'
assert_count '| 默认 | 面试回答与追问链 |' 1 '默认表达风格唯一'
assert_contains "$INDEX" 'methods/progressive-dialogue.md' '索引注册渐进式方法'
assert_contains "$INDEX" 'methods/problem-first-design.md' '索引注册问题先行方法'
assert_contains "$INDEX" 'styles/interview-answer.md' '索引注册面试表达风格'

printf '\n路由目标\n'
assert_file "$ROOT/prompts/teaching/methods/progressive-dialogue.md" '渐进式方法文件存在'
assert_file "$ROOT/prompts/teaching/methods/problem-first-design.md" '问题先行方法文件存在'
assert_file "$ROOT/prompts/teaching/styles/interview-answer.md" '面试表达风格文件存在'

printf '\n默认协议\n'
progressive="$ROOT/prompts/teaching/methods/progressive-dialogue.md"
assert_contains "$progressive" '首轮禁止给出完整答案' '渐进式方法限制首轮完整答案'
assert_contains "$progressive" '每轮结尾必须只提出**一个理解检查问题**' '渐进式方法限制理解检查数量'
assert_contains "$progressive" '用户回答前不得继续下一个子概念' '渐进式方法等待用户回答'
assert_contains "$progressive" '只有用户明确要求' '渐进式方法定义退出条件'

style="$ROOT/prompts/teaching/styles/interview-answer.md"
assert_contains "$style" '仅覆盖默认渐进式方法中的三项规则' '面试风格声明局部覆盖'
assert_contains "$style" '2–4 个' '面试风格限制追问数量'
assert_contains "$style" '无需等待用户回答' '面试风格声明直接回答追问'
assert_contains "$style" '真实性约束' '面试风格保留真实性约束'

if [ "$FAILS" -ne 0 ]; then
  printf '\n%d 项失败\n' "$FAILS"
  exit 1
fi
printf '\n全部通过\n'
