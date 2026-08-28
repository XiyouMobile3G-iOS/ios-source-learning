#!/bin/bash
#
# tests/progress.test.sh —— progress.sh 的行为测试
#
#   ./tests/progress.test.sh
#
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../progress.sh
. "$ROOT/progress.sh"

FAILS=0
assert_eq() {
  local got="$1" want="$2" name="$3"
  if [ "$got" = "$want" ]; then
    printf '  ok  %s\n' "$name"
  else
    printf '  FAIL %s\n    got:  %s\n    want: %s\n' "$name" "$got" "$want"
    FAILS=$((FAILS + 1))
  fi
}

assert_ok() {
  local name="$1"
  shift
  if "$@"; then
    printf '  ok  %s\n' "$name"
  else
    printf '  FAIL %s（期望成功）\n' "$name"
    FAILS=$((FAILS + 1))
  fi
}

assert_fail() {
  local name="$1"
  shift
  if "$@"; then
    printf '  FAIL %s（期望失败）\n' "$name"
    FAILS=$((FAILS + 1))
  else
    printf '  ok  %s\n' "$name"
  fi
}

PROGRESS_FILL='#'
PROGRESS_EMPTY='-'

printf '是否画条\n'
PROGRESS_FORCE=1
assert_ok 'PROGRESS_FORCE 时画条' progress_active
unset PROGRESS_FORCE
if [ -t 2 ]; then
  assert_ok 'TTY 时画条' progress_active
else
  assert_fail '非 TTY 且无 FORCE 不画条' progress_active
fi

printf '进度条绘制\n'
assert_eq "$(progress_bar_string 10 0)"   '----------' '0% 全空'
assert_eq "$(progress_bar_string 10 100)" '##########' '100% 全满'
assert_eq "$(progress_bar_string 10 50)"  '#####-----' '50% 一半'
assert_eq "$(progress_bar_string 10 33)"  '###-------' '33% 向下取整'
assert_eq "$(progress_bar_string 10 -1)"   '----------' '负百分比限制为 0'

printf '阶段加权（条只往前走）\n'
assert_eq "$(progress_phase_pct 枚举 0)"   '0'  '枚举 0% → 0'
assert_eq "$(progress_phase_pct 枚举 100)" '5'  '枚举 100% → 5'
assert_eq "$(progress_phase_pct 压缩 0)"   '5'  '压缩 0% → 5'
assert_eq "$(progress_phase_pct 压缩 100)" '10' '压缩 100% → 10'
assert_eq "$(progress_phase_pct 下载 0)"   '10' '下载 0% → 10'
assert_eq "$(progress_phase_pct 下载 50)"  '50' '下载 50% → 50'
assert_eq "$(progress_phase_pct 下载 100)" '90' '下载 100% → 90'
assert_eq "$(progress_phase_pct 解包 0)"   '90' '解包 0% → 90'
assert_eq "$(progress_phase_pct 解包 100)" '100' '解包 100% → 100'

printf '整体百分比（已完成仓库 + 当前仓库进度）\n'
assert_eq "$(progress_overall_pct 0 0 5)"   '0'  '尚未开始'
assert_eq "$(progress_overall_pct 0 50 5)"  '10' '第 1/5 个下到一半 → 10%'
assert_eq "$(progress_overall_pct 1 50 5)"  '30' '第 2/5 个下到一半 → 30%'
assert_eq "$(progress_overall_pct 5 0 5)"   '100' '五个都完成'
assert_eq "$(progress_overall_pct 5 100 5)"  '100' '完成数已到总数时仍不超过 100%'
assert_eq "$(progress_overall_pct 6 100 5)"  '100' '完成数超过总数时限制为 100%'
assert_eq "$(progress_overall_pct 0 0 0)"   '0'  '总数为 0 不除零'

printf '解析 git clone/fetch 进度行\n'
assert_ok 'Receiving objects 带速度' \
  progress_parse_git_line 'Receiving objects:  45% (555/1234), 12.30 MiB | 2.10 MiB/s'
assert_eq "$PROGRESS_PCT" '45' 'Receiving percent'
assert_eq "$PROGRESS_PHASE" '下载' 'Receiving phase'
assert_eq "$PROGRESS_DETAIL" '12.30 MiB | 2.10 MiB/s' 'Receiving size/speed'

assert_ok 'Receiving objects 多空格对齐的速度' \
  progress_parse_git_line 'Receiving objects:  45% (555/1234), 12.30 MiB  |  2.10 MiB/s'
assert_eq "$PROGRESS_DETAIL" '12.30 MiB | 2.10 MiB/s' 'Receiving 多空格 size/speed'

assert_ok 'Receiving objects 100% done' \
  progress_parse_git_line 'Receiving objects: 100% (1234/1234), 50.20 MiB | 3.10 MiB/s, done.'
assert_eq "$PROGRESS_PCT" '100' 'Receiving done percent'

assert_ok '阶段前的远程百分比不误匹配' \
  progress_parse_git_line 'remote: 50% complete; Receiving objects: 20% (2/10)'
assert_eq "$PROGRESS_PCT" '20' 'Receiving 使用阶段后的百分比'

assert_ok 'Resolving deltas' \
  progress_parse_git_line 'Resolving deltas:  80% (400/500)'
assert_eq "$PROGRESS_PCT" '80' 'Resolving percent'
assert_eq "$PROGRESS_PHASE" '解包' 'Resolving phase'

assert_ok 'remote Counting objects' \
  progress_parse_git_line 'remote: Counting objects:  12% (148/1234)'
assert_eq "$PROGRESS_PCT" '12' 'Counting percent'
assert_eq "$PROGRESS_PHASE" '枚举' 'Counting phase'

assert_ok 'remote Compressing objects' \
  progress_parse_git_line 'remote: Compressing objects: 100% (567/567), done.'
assert_eq "$PROGRESS_PHASE" '压缩' 'Compressing phase'

assert_fail '普通日志不是进度行' \
  progress_parse_git_line 'Cloning into foo...'

assert_fail '空行不是进度行' \
  progress_parse_git_line ''

printf '消费 \\r 刷新的 git 进度流\n'
PROGRESS_FORCE=1
PROGRESS_NEWLINE=1
log="$(mktemp)"
consume_before=$FAILS
out="$(
  printf 'Receiving objects:  10%% (10/100), 1.00 MiB | 1.00 MiB/s\rReceiving objects: 100%% (100/100), 9.00 MiB | 2.00 MiB/s, done.\nResolving deltas: 100%% (5/5), done.\nCloning into x...\n' \
    | progress_consume 'objc4' "$log" 0 2 2>&1
)"
# 第 1/2 个仓库：下载 10% → 仓库 18% → 整体 9%；下载 100% → 90% → 整体 45%；解包 100% → 100% → 整体 50%
printf '%s\n' "$out" | grep -q '  9%' || { printf '  FAIL 消费流未画出 9%%\n%s\n' "$out"; FAILS=$((FAILS + 1)); }
printf '%s\n' "$out" | grep -q ' 45%' || { printf '  FAIL 消费流未画出 45%%\n%s\n' "$out"; FAILS=$((FAILS + 1)); }
printf '%s\n' "$out" | grep -q ' 50%' || { printf '  FAIL 消费流未画出 50%%\n%s\n' "$out"; FAILS=$((FAILS + 1)); }
grep -qx 'Cloning into x...' "$log" || { printf '  FAIL 非进度行应写入 log\n'; FAILS=$((FAILS + 1)); }
if [ "$FAILS" -eq "$consume_before" ]; then
  printf '  ok  消费 \\r 进度流并透传非进度行\n'
fi
rm -f "$log"

log="$(mktemp)"
nl_before=$FAILS
out="$(
  printf 'Receiving objects:  10%% (10/100), 1.00 MiB | 1.00 MiB/s\nReceiving objects: 100%% (100/100), 9.00 MiB | 2.00 MiB/s, done.\nResolving deltas: 100%% (5/5), done.\nCloning into x...\n' \
    | progress_consume 'objc4' "$log" 0 2 2>&1
)"
printf '%s\n' "$out" | grep -q '  9%' || { printf '  FAIL 纯换行流未画出 9%%\n%s\n' "$out"; FAILS=$((FAILS + 1)); }
printf '%s\n' "$out" | grep -q ' 50%' || { printf '  FAIL 纯换行流未画出解包 50%%\n%s\n' "$out"; FAILS=$((FAILS + 1)); }
grep -qx 'Cloning into x...' "$log" || { printf '  FAIL 纯换行流非进度行应写入 log\n'; FAILS=$((FAILS + 1)); }
if [ "$FAILS" -eq "$nl_before" ]; then
  printf '  ok  纯 \\n 进度流也能按行切开\n'
fi
rm -f "$log"

printf 'stderr 控制序列\n'
assert_eq "$(progress_sanitize_line $'\033[31mfatal: nope\033[0m')" 'fatal: nope' 'CSI 颜色码'
assert_eq "$(progress_sanitize_line $'\033]0;pwned\007hello')" 'hello' 'OSC 窗口标题'
assert_eq "$(progress_sanitize_line $'a\tb')" $'a\tb' 'tab 保留'
assert_eq "$(progress_sanitize_line 'fatal: repository not found')" 'fatal: repository not found' '普通错误原样'
assert_eq "$(progress_sanitize_line $'\033[31m下载失败\033[0m')" '下载失败' 'UTF-8 不受影响'
assert_eq "$(progress_redact_line 'fatal: https://user:secret@github.com/a/b.git?token=abc&ref=main')" 'fatal: https://github.com/a/b.git?token=REDACTED&ref=main' '失败日志脱敏 URL 凭据'
assert_eq "$(progress_redact_line 'fatal: https://github.com/a/b.git?X-Amz-Signature=abc')" 'fatal: https://github.com/a/b.git?X-Amz-Signature=REDACTED' '失败日志脱敏签名参数'

printf 'git_run_progress 包装假 git\n'
PROGRESS_FORCE=1
PROGRESS_NEWLINE=1
fake_git_progress() {
  printf 'Cloning into foo...\n' >&2
  printf 'Receiving objects:  50%% (50/100), 4.00 MiB | 1.00 MiB/s\r' >&2
  printf 'Receiving objects: 100%% (100/100), 9.00 MiB | 2.00 MiB/s, done.\n' >&2
  printf 'Resolving deltas: 100%% (5/5), done.\n' >&2
  return 0
}
wrap_before=$FAILS
wrap_out="$(git_run_progress 'demo' 0 1 fake_git_progress 2>&1)"
printf '%s\n' "$wrap_out" | grep -q ' 50%' || { printf '  FAIL 包装未画出下载过半 50%%\n%s\n' "$wrap_out"; FAILS=$((FAILS + 1)); }
printf '%s\n' "$wrap_out" | grep -q '100%' || { printf '  FAIL 包装未画出解包完成 100%%\n%s\n' "$wrap_out"; FAILS=$((FAILS + 1)); }
printf '%s\n' "$wrap_out" | grep -q 'Cloning into foo' && { printf '  FAIL 成功时不应回放非进度行\n%s\n' "$wrap_out"; FAILS=$((FAILS + 1)); }
if [ "$FAILS" -eq "$wrap_before" ]; then
  printf '  ok  包装假 git 只画进度条\n'
fi

fake_git_fail() {
  printf 'fatal: repository not found\n' >&2
  return 128
}
wrap_before=$FAILS
wrap_out="$(git_run_progress 'demo' 0 1 fake_git_fail 2>&1)" || wrap_st=$?
[ "${wrap_st:-0}" -eq 128 ] || { printf '  FAIL 失败退出码应为 128，实际 %s\n' "${wrap_st:-0}"; FAILS=$((FAILS + 1)); }
printf '%s\n' "$wrap_out" | grep -q 'fatal: repository not found' || { printf '  FAIL 失败时应回放 git 错误\n%s\n' "$wrap_out"; FAILS=$((FAILS + 1)); }
if [ "$FAILS" -eq "$wrap_before" ]; then
  printf '  ok  失败时回放 git 错误并保留退出码\n'
fi

fake_git_ansi() {
  printf '\033[31mfatal: repository not found\033[0m\n' >&2
  printf '\033]0;pwned\007hint: also a hint\n' >&2
  return 128
}
wrap_before=$FAILS
wrap_st=0
wrap_out="$(git_run_progress 'demo' 0 1 fake_git_ansi 2>&1)" || wrap_st=$?
[ "$wrap_st" -eq 128 ] || { printf '  FAIL ANSI 失败退出码应为 128，实际 %s\n' "$wrap_st"; FAILS=$((FAILS + 1)); }
case "$wrap_out" in
  *$'\033'*) printf '  FAIL 回放不应含 ESC\n%s\n' "$wrap_out"; FAILS=$((FAILS + 1)) ;;
esac
printf '%s\n' "$wrap_out" | grep -q 'fatal: repository not found' || { printf '  FAIL 剥离后仍应有 fatal 文本\n%s\n' "$wrap_out"; FAILS=$((FAILS + 1)); }
printf '%s\n' "$wrap_out" | grep -q 'hint: also a hint' || { printf '  FAIL 非 fatal 前缀的行也要回放\n%s\n' "$wrap_out"; FAILS=$((FAILS + 1)); }
if [ "$FAILS" -eq "$wrap_before" ]; then
  printf '  ok  失败回放剥控制序列且保留 hint\n'
fi

printf 'RETURN trap 恢复\n'
PROGRESS_FORCE=1
PROGRESS_NEWLINE=1
trap 'progress_test_return_trap=1' RETURN
return_trap_before="$(trap -p RETURN)"
git_run_progress 'demo' 0 1 fake_git_progress >/dev/null 2>&1
return_trap_after="$(trap -p RETURN)"
assert_eq "$return_trap_after" "$return_trap_before" '保留调用方已有 RETURN trap'
trap - RETURN

printf '临时日志不泄漏\n'
_tmp=$(mktemp -d)
TMPDIR="$_tmp"
export TMPDIR
PROGRESS_FORCE=1
PROGRESS_NEWLINE=1
git_run_progress 'demo' 0 1 fake_git_progress >/dev/null 2>&1 || true
git_run_progress 'demo' 0 1 fake_git_fail >/dev/null 2>&1 || true
leftover=$(find "$_tmp" -type f | wc -l | tr -d ' ')
assert_eq "$leftover" '0' '成功和失败后都没有留下 mktemp 文件'
rm -rf "$_tmp"
unset TMPDIR

printf 'clone / fetch 谓词\n'
# shellcheck source=../sources.sh
. "$ROOT/sources.sh"
_src=$(mktemp -d)
SOURCES_ROOT="$_src"
assert_ok '目录不存在 → 需要 clone' source_needs_clone missing
assert_fail '目录不存在 → 不是已有仓库' source_has_repo missing
mkdir "$_src/occupied"
assert_fail '被占用 → 不 clone' source_needs_clone occupied
assert_fail '被占用 → 不是仓库' source_has_repo occupied
mkdir -p "$_src/repo/.git"
assert_fail '已是仓库 → 不 clone' source_needs_clone repo
assert_ok '已是仓库 → 可 fetch' source_has_repo repo
rm -rf "$_src"

_src=$(mktemp -d)
SOURCES_ROOT="$_src"
assert_eq "$(source_count source_needs_clone jsonmodel)" '1' '缺目录时 clone 计数 1'
assert_eq "$(source_count source_has_repo jsonmodel)" '0' '缺目录时 fetch 计数 0'
mkdir -p "$_src/third-party/JSONModel/.git"
assert_eq "$(source_count source_needs_clone jsonmodel)" '0' '已有仓库时 clone 计数 0'
assert_eq "$(source_count source_has_repo jsonmodel)" '1' '已有仓库时 fetch 计数 1'
assert_eq "$(source_redact_url 'https://user:token@github.com/a/b.git')" 'https://github.com/a/b.git' '去掉 URL 里的 user:token'
assert_eq "$(source_redact_url 'https://github.com/a/b.git')" 'https://github.com/a/b.git' '无凭证的 URL 原样返回'
assert_eq "$(source_redact_url 'https://github.com/a/b.git?access_token=secret&ref=main')" 'https://github.com/a/b.git?access_token=REDACTED&ref=main' '去掉 query 里的 access token'
assert_eq "$(source_redact_url 'ssh://git@github.com/a/b.git?token=secret')" 'ssh://github.com/a/b.git?token=REDACTED' '去掉 SSH user 和 query token'
rm -rf "$_src"

if [ "$FAILS" -ne 0 ]; then
  printf '\n%s 个失败\n' "$FAILS"
  exit 1
fi
printf '\n全部通过\n'
exit 0
