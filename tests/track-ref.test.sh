#!/bin/bash
#
# tests/track-ref.test.sh —— track 策略必须校验 sources.sh 的 ref
#
#   ./tests/track-ref.test.sh
#
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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

assert_contains() {
  local haystack="$1" needle="$2" name="$3"
  case "$haystack" in
    *"$needle"*) printf '  ok  %s\n' "$name" ;;
    *)
      printf '  FAIL %s\n    missing: %s\n    in: %s\n' "$name" "$needle" "$haystack"
      FAILS=$((FAILS + 1))
      ;;
  esac
}

assert_not_contains() {
  local haystack="$1" needle="$2" name="$3"
  case "$haystack" in
    *"$needle"*)
      printf '  FAIL %s\n    unexpectedly found: %s\n    in: %s\n' "$name" "$needle" "$haystack"
      FAILS=$((FAILS + 1))
      ;;
    *) printf '  ok  %s\n' "$name" ;;
  esac
}

# 隔离工作区：真实脚本 + 只含 fixture 的清单 + 本地 bare 远端。
# fixture 配成 track|main；测试再把它切到 feature / 游离 HEAD。
setup_ws() {
  WS=$(mktemp -d)
  REMOTE=$(mktemp -d)
  SEED=$(mktemp -d)

  git init --bare -q -b main "$REMOTE"
  git -C "$SEED" init -q -b main
  git -C "$SEED" config user.email test@example.com
  git -C "$SEED" config user.name test
  printf 'seed\n' > "$SEED/file"
  git -C "$SEED" add file
  git -C "$SEED" commit -q -m c1
  git -C "$SEED" remote add origin "$REMOTE"
  git -C "$SEED" push -q -u origin main
  git -C "$SEED" checkout -q -b feature
  git -C "$SEED" push -q -u origin feature

  git clone -q "$REMOTE" "$WS/fixture"
  git -C "$WS/fixture" config user.email test@example.com
  git -C "$WS/fixture" config user.name test
  git -C "$WS/fixture" checkout -q -B feature origin/feature

  cp "$ROOT/check-updates.sh" "$ROOT/update-sources.sh" "$ROOT/progress.sh" "$WS/"
  {
    printf 'SOURCES=(\n'
    printf '  "fixture|fixture|Fixture|%s|track|main|"\n' "$REMOTE"
    printf ')\n'
    awk '/^# ── 查询/{p=1} p' "$ROOT/sources.sh"
  } > "$WS/sources.sh"
  chmod +x "$WS/check-updates.sh" "$WS/update-sources.sh"
}

cleanup_ws() {
  rm -rf "$WS" "$REMOTE" "$SEED"
}

printf 'check-updates：当前分支与 ref 不符\n'
setup_ws
st=0
out="$("$WS/check-updates.sh" --no-cache fixture)" || st=$?
assert_eq "$st" '2' '分支不符时退出码 2'
assert_contains "$out" '配置要求分支 main，当前在 feature，请先切回 main' '明细指出配置分支与当前分支'
assert_not_contains "$out" 'UPTODATE' '不得把错误分支判为最新'
assert_not_contains "$out" '最新（feature@' '不得按 feature 报最新'
cleanup_ws

printf 'update-sources：当前分支与 ref 不符\n'
setup_ws
before="$(git -C "$WS/fixture" rev-parse HEAD)"
st=0
out="$("$WS/update-sources.sh" fixture)" || st=$?
after="$(git -C "$WS/fixture" rev-parse HEAD)"
assert_eq "$st" '0' '分支不符时沿用跳过约定，退出码 0'
assert_eq "$after" "$before" '不得移动 HEAD'
assert_contains "$out" '配置要求分支 main，当前在 feature，请先切回再更新' '提示切回配置分支'
assert_contains "$out" '分支不符' '摘要标记分支不符'
assert_not_contains "$out" '已 fetch' '不得 fetch 错误分支'
cleanup_ws

printf 'update-sources：-n / -f 不能旁路分支守卫\n'
setup_ws
before="$(git -C "$WS/fixture" rev-parse HEAD)"
out_n="$("$WS/update-sources.sh" -n fixture)"
out_f="$("$WS/update-sources.sh" -f fixture)"
after="$(git -C "$WS/fixture" rev-parse HEAD)"
assert_eq "$after" "$before" '-n/-f 都不得移动 HEAD'
assert_contains "$out_n" '分支不符' '-n 仍拦截'
assert_contains "$out_f" '分支不符' '-f 仍拦截'
assert_not_contains "$out_n" '[dry-run] git fetch' '-n 不得走到 fetch 演练'
cleanup_ws

printf '游离 HEAD\n'
setup_ws
git -C "$WS/fixture" checkout -q --detach HEAD
st=0
out="$("$WS/check-updates.sh" --no-cache fixture)" || st=$?
assert_eq "$st" '2' '游离 HEAD 时 check 退出码 2'
assert_contains "$out" 'HEAD 处于游离状态' 'check 报告游离 HEAD'
st=0
out="$("$WS/update-sources.sh" fixture)" || st=$?
assert_eq "$st" '0' '游离 HEAD 时 update 退出码 0'
assert_contains "$out" '游离 HEAD' 'update 把 HEAD 显示为游离 HEAD'
assert_not_contains "$out" '已 fetch' '游离 HEAD 不得 fetch'
cleanup_ws

printf '切回 main 后恢复正常路径\n'
setup_ws
git -C "$WS/fixture" checkout -q main
st=0
out="$("$WS/check-updates.sh" --no-cache fixture)" || st=$?
assert_eq "$st" '0' '在 main 上 check 退出码 0'
assert_contains "$out" 'UPTODATE' '在 main 上判定最新'
st=0
out="$("$WS/update-sources.sh" fixture)" || st=$?
assert_eq "$st" '0' '在 main 上 update 退出码 0'
assert_contains "$out" '已 fetch' '在 main 上允许 fetch'
assert_contains "$out" '已是最新' '与 origin/main 同步'
cleanup_ws

if [ "$FAILS" -ne 0 ]; then
  printf '\n%d 项失败\n' "$FAILS"
  exit 1
fi
printf '\n全部通过\n'
exit 0
