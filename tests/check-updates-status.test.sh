#!/bin/bash
#
# tests/check-updates-status.test.sh —— 混合检查状态必须优先报告 ERROR
#
#   ./tests/check-updates-status.test.sh
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

WS="$(mktemp -d)"
REMOTE="$(mktemp -d)"
SEED="$(mktemp -d)"
cleanup() {
  rm -rf "$WS" "$REMOTE" "$SEED"
}
trap cleanup EXIT

git init --bare -q "$REMOTE"
git --git-dir="$REMOTE" symbolic-ref HEAD refs/heads/main
git -C "$SEED" init -q
git -C "$SEED" symbolic-ref HEAD refs/heads/main
git -C "$SEED" config user.email test@example.com
git -C "$SEED" config user.name test
printf 'first\n' > "$SEED/file"
git -C "$SEED" add file
git -C "$SEED" commit -q -m c1
git -C "$SEED" remote add origin "$REMOTE"
git -C "$SEED" push -q -u origin main
git clone -q "$REMOTE" "$WS/stale"
printf 'second\n' >> "$SEED/file"
git -C "$SEED" add file
git -C "$SEED" commit -q -m c2
git -C "$SEED" push -q origin main

cp "$ROOT/check-updates.sh" "$WS/"
helpers="$(awk '/^source_lookup\(\)/ { p=1 } p' "$ROOT/sources.sh")"
{
  printf 'SOURCES=(\n'
  printf '  "stale|stale|Stale|%s|track|main|"\n' "$REMOTE"
  printf '  "missing|missing|Missing|%s|track|main|"\n' "$REMOTE"
  printf ')\n'
  printf '%s\n' "$helpers"
} > "$WS/sources.sh"
chmod +x "$WS/check-updates.sh"

printf '混合 UPDATE + ERROR\n'
st=0
out="$(bash "$WS/check-updates.sh" --no-cache stale missing)" || st=$?
assert_eq "$st" '2' '检查失败优先返回 2'
assert_contains "$out" 'ERROR 检查失败' '总览报告 ERROR'
assert_contains "$out" 'Stale: main@' '仍列出已发现的更新'
assert_contains "$out" 'Missing: 本地没有源码' '列出失败目标'

if [ "$FAILS" -ne 0 ]; then
  printf '\n%d 项失败\n' "$FAILS"
  exit 1
fi
printf '\n全部通过\n'
