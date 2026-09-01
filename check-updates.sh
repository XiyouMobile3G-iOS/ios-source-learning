#!/bin/bash
#
# check-updates.sh —— 只检查、不改动：判断源码仓库是否需要更新
#
#   ./check-updates.sh           检查（带缓存），输出一行结论
#   ./check-updates.sh -v        详细模式，逐仓库列出本地/远端版本
#   ./check-updates.sh -f        忽略缓存，强制走网络
#   ./check-updates.sh --ttl 3600   自定义缓存有效期（秒，默认 21600 = 6h）
#   ./check-updates.sh --no-cache   不读也不写缓存
#   ./check-updates.sh objc4 cf  只检查指定目标
#   ./check-updates.sh -h        帮助
#
# 目标（Apple 底层）：objc4 / libdispatch / libdispatch-apple / foundation / swift-foundation / cf
# 目标（参照实现）：  gnustep
# 目标（第三方库）：  afnetworking / jsonmodel / sdwebimage
# 目标清单与各自的更新策略都在同目录的 sources.sh，三个脚本共用。
#
# 退出码（给 agent 判断用）：
#   0  全部最新 —— 不需要跑 update-sources.sh
#   10 有更新   —— 应该跑 ./update-sources.sh
#   2  检查失败（网络等）—— 按「未能更新」处理，声明基于本地版本作答
#
# 与 update-sources.sh 的区别：本脚本用 git ls-remote / curl HEAD 探测，
# 不 fetch、不写 .git、不碰工作区，几秒内返回，输出极简以节省 agent 上下文。
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$ROOT/.update-check-cache"

# 源码清单：与 bootstrap.sh / update-sources.sh 共用的单一事实来源
if [ ! -f "$ROOT/sources.sh" ]; then
  printf 'ERROR 缺少 sources.sh（源码清单）\n' >&2
  exit 2
fi
# shellcheck source=sources.sh
. "$ROOT/sources.sh"

VERBOSE=0
FORCE=0
USE_CACHE=1
TTL=21600
NET_TIMEOUT=25

usage() {
  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"
  exit 0
}

# ── 参数解析 ────────────────────────────────────────────────────────────
TARGETS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -v|--verbose)  VERBOSE=1 ;;
    -f|--force)    FORCE=1 ;;
    --no-cache)    USE_CACHE=0 ;;
    --ttl)         TTL="${2:-}"
                   case "$TTL" in ''|*[!0-9]*) printf -- '--ttl 需要一个秒数\n' >&2; exit 1 ;; esac
                   shift ;;
    -h|--help)     usage ;;
    -*)            printf '未知参数 %s\n' "$1" >&2; exit 1 ;;
    *)             TARGETS+=("$1") ;;
  esac
  shift
done

ALL_TARGETS=()
while IFS= read -r k; do ALL_TARGETS+=("$k"); done < <(source_all_keys)
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=("${ALL_TARGETS[@]}")

for t in "${TARGETS[@]}"; do
  source_lookup "$t" || { printf 'ERROR 未知目标 %s（可用：%s）\n' "$t" "${ALL_TARGETS[*]}" >&2; exit 2; }
done

wants() {
  local t
  for t in "${TARGETS[@]}"; do [ "$t" = "$1" ] && return 0; done
  return 1
}

# ── 缓存（按目标分文件）────────────────────────────────────────────────
# 每个目标一个文件 .update-check-cache/<目标>：
#   第 1 行 epoch，第 2 行 "<状态>\t<一句话说明>"
# 分文件是为了让「只查部分目标」也能命中缓存——agent 常会只查它关心的那个，
# 早先的整体签名缓存在这种用法下永远失效。
cache_get() {
  local key="$1" file="$CACHE_DIR/$1" ts age
  [ "$USE_CACHE" -eq 1 ] && [ "$FORCE" -eq 0 ] && [ -f "$file" ] || return 1
  ts="$(head -1 "$file")"
  case "$ts" in ''|*[!0-9]*) return 1 ;; esac
  age=$(( $(date +%s) - ts ))
  [ "$age" -ge 0 ] && [ "$age" -lt "$TTL" ] || return 1
  tail -n +2 "$file" > "$TMPDIR_/$key" 2>/dev/null || return 1
  [ -s "$TMPDIR_/$key" ] || return 1
  return 0
}

cache_put() {
  local key="$1"
  [ "$USE_CACHE" -eq 1 ] || return 0
  # 探测失败不入缓存，否则网络恢复后仍会连报 TTL 小时的 ERROR
  grep -q '^error	' "$TMPDIR_/$key" && return 0
  mkdir -p "$CACHE_DIR" 2>/dev/null || return 0
  # 先写临时文件再 mv：同一目录内 rename 是原子的，多个 agent 并发跑时
  # 读者要么看到旧内容要么看到新内容，不会撞见写了一半的文件
  local tmp="$CACHE_DIR/.tmp.$key.$$"
  { date +%s; cat "$TMPDIR_/$key"; } > "$tmp" 2>/dev/null \
    && mv -f "$tmp" "$CACHE_DIR/$key" 2>/dev/null
  rm -f "$tmp" 2>/dev/null
  return 0
}

# ── 带超时执行（macOS 无 timeout(1)）────────────────────────────────────
run_timeout() {
  local secs="$1"; shift
  "$@" &
  local pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local watcher=$!
  wait "$pid"; local rc=$?
  kill -TERM "$watcher" 2>/dev/null
  return $rc
}

# ── 单仓库检查 ──────────────────────────────────────────────────────────
# 结果写入 "$TMPDIR_/<key>"，格式：<状态>\t<一句话说明>
#   状态：ok | update | notice | error
#
# update 与 notice 的区别，直接对应 update-sources.sh 到底能不能自动收敛：
#   update  跑一次 update-sources.sh 就解决 —— 退出码 10
#   notice  update-sources.sh 按策略不会动工作区，必须人工处理 —— 退出码不变
# 若把 notice 也算作 update，agent 每轮都会被驱使跑一次注定无效的
# update-sources.sh，反而白烧上下文（objc4 的 fetch-only 策略正是这种情况）。
#
# 判定核心：拿到远端最新 commit sha 后，用本地对象库直接判断——
# 该 commit 在本地存在且是 HEAD 的祖先 ⇒ 最新；否则 ⇒ 有更新。
# 全程只读远端 refs，不下载对象。
#
# mode：branch（追 tracking 分支）| tag（追最高版本 tag）| tag-manual（同 tag，但只提示）
# $5 tag 过滤 glob（可空）  $6 清单指定的 ref（可空；branch 模式下校验当前分支）
check_git_repo() {
  local key="$1" dir="$ROOT/$2" name="$3" mode="$4" tagglob="${5:-}" ref="${6:-}" out="$TMPDIR_/$1"

  # 本地核对：源码都没下载就别谈更新，直接把该跑的命令给出来
  if [ ! -d "${dir}/.git" ]; then
    if [ -e "${dir}" ]; then
      printf 'error\t%s: 目录存在但不是 git 仓库，先移走再跑 ./bootstrap.sh %s\n' "$name" "$key" > "$out"
    else
      printf 'error\t%s: 本地没有源码，先跑 ./bootstrap.sh %s\n' "$name" "$key" > "$out"
    fi
    return
  fi

  local head_sha remote_sha remote_desc
  head_sha="$(git -C "$dir" rev-parse HEAD 2>/dev/null)"

  if [ "$mode" = "branch" ]; then
    local branch remote ls
    branch="$(git -C "$dir" symbolic-ref --short -q HEAD)"
    if [ -z "$branch" ]; then
      printf 'error\t%s: HEAD 处于游离状态，无法按分支比对\n' "$name" > "$out"; return
    fi
    # 清单指定了 ref 时以 ref 为准：本地误切到别的分支不算有效的最新版本
    if [ -n "$ref" ] && [ "$branch" != "$ref" ]; then
      printf 'error\t%s: 配置要求分支 %s，当前在 %s，请先切回 %s\n' "$name" "$ref" "$branch" "$ref" > "$out"; return
    fi
    remote="$(git -C "$dir" config "branch.${branch}.remote" 2>/dev/null || true)"
    [ -z "$remote" ] && remote=origin
    ls="$(run_timeout "$NET_TIMEOUT" git -C "$dir" ls-remote "$remote" "refs/heads/${branch}" 2>/dev/null)"
    remote_sha="$(printf '%s' "$ls" | awk 'NR==1{print $1}')"
    remote_desc="${branch}@${remote_sha:0:7}"
  else
    # tag 模式：远端版本号最高的 tag
    # tagglob 非空时只让 git 返回匹配的 tag——否则仓库里的非版本号历史 tag
    # 会被 sort -V 排到最高，报出永远消不掉的假「有新版本」（见 sources.sh）。
    local ls tag
    ls="$(run_timeout "$NET_TIMEOUT" git -C "$dir" ls-remote --tags origin ${tagglob:+"$tagglob"} 2>/dev/null)"
    tag="$(printf '%s' "$ls" | awk '{print $2}' | sed 's|^refs/tags/||; s|\^{}$||' \
           | grep -v '^$' | sort -Vu | tail -1)"
    if [ -n "$tag" ]; then
      # 优先取解引用后的 commit sha（annotated tag）
      remote_sha="$(printf '%s' "$ls" | awk -v t="refs/tags/${tag}^{}" '$2==t{print $1}' | head -1)"
      [ -z "$remote_sha" ] && remote_sha="$(printf '%s' "$ls" | awk -v t="refs/tags/${tag}" '$2==t{print $1}' | head -1)"
    fi
    remote_desc="$tag"
  fi

  if [ -z "${remote_sha:-}" ]; then
    printf 'error\t%s: 探测远端失败（网络 / 权限 / 超时）\n' "$name" > "$out"; return
  fi

  local local_desc
  if [ "$mode" = "branch" ]; then
    local_desc="$(git -C "$dir" symbolic-ref --short -q HEAD)@${head_sha:0:7}"
  else
    local_desc="$(git -C "$dir" describe --tags --exact-match HEAD 2>/dev/null \
                  || git -C "$dir" describe --tags --abbrev=0 HEAD 2>/dev/null \
                  || printf '%s' "${head_sha:0:7}")"
  fi

  if [ "$remote_sha" = "$head_sha" ] \
     || { git -C "$dir" cat-file -e "${remote_sha}^{commit}" 2>/dev/null \
          && git -C "$dir" merge-base --is-ancestor "$remote_sha" "$head_sha" 2>/dev/null; }; then
    printf 'ok\t%s: 最新（%s）\n' "$name" "$local_desc" > "$out"
    return
  fi

  if [ "$mode" = "tag-manual" ]; then
    printf 'notice\t%s: 有新版本 %s（当前 %s）。update-sources.sh 对它只 fetch 不切换，需人工 checkout / rebase\n' \
      "$name" "$remote_desc" "$local_desc" > "$out"
    return
  fi

  # 工作区脏时 update-sources.sh 默认跳过，提前说清楚，省得跑一趟无功而返
  local dirty
  dirty="$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  if [ "${dirty:-0}" -gt 0 ]; then
    printf 'update\t%s: %s → %s（工作区有 %s 处改动，需 ./update-sources.sh -f %s）\n' \
      "$name" "$local_desc" "$remote_desc" "$dirty" "$key" > "$out"
  else
    printf 'update\t%s: %s → %s\n' "$name" "$local_desc" "$remote_desc" > "$out"
  fi
}

# ── 主流程 ──────────────────────────────────────────────────────────────
TMPDIR_="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_"' EXIT

# 缓存过期（或被 -f/--no-cache 绕过）的目标才走网络，各目标并行探测
FRESH=()
probe() {  # $1 目标名，其余为检查命令
  local key="$1"; shift
  cache_get "$key" && return 0
  FRESH+=("$key")
  "$@" &
}

# 清单里的策略在这里翻译成探测模式：
#   pinned → tag-manual  钉住的 tag，有新版本只提示，不驱使 update-sources.sh（跑了也不会动）
#   track  → branch      追踪分支
#   latest → tag         追最新 tag
for key in "${ALL_TARGETS[@]}"; do
  wants "$key" || continue
  source_lookup "$key" || continue
  case "$SRC_POLICY" in
    pinned) mode=tag-manual ;;
    latest) mode=tag ;;
    *)      mode=branch ;;
  esac
  probe "$SRC_KEY" check_git_repo "$SRC_KEY" "$SRC_DIR" "$SRC_NAME" "$mode" "$SRC_TAGGLOB" "$SRC_REF"
done
wait

for key in ${FRESH+"${FRESH[@]}"}; do
  [ -s "$TMPDIR_/$key" ] && cache_put "$key"
done

UPDATES=""; ERRORS=""; NOTICES=""; OKS=""
for key in "${ALL_TARGETS[@]}"; do
  [ -f "$TMPDIR_/$key" ] || continue
  line="$(cat "$TMPDIR_/$key")"
  case "${line%%$'\t'*}" in
    update) UPDATES="${UPDATES}  ${line#*$'\t'}"$'\n' ;;
    notice) NOTICES="${NOTICES}  ${line#*$'\t'}"$'\n' ;;
    error)  ERRORS="${ERRORS}  ${line#*$'\t'}"$'\n' ;;
    ok)     OKS="${OKS}  ${line#*$'\t'}"$'\n' ;;
  esac
done

BODY=""
CODE=0
if [ -n "$ERRORS" ]; then
  BODY="ERROR 检查失败，按「未能更新、基于本地版本」处理"$'\n'
  CODE=2
elif [ -n "$UPDATES" ]; then
  BODY="UPDATE 有更新，请运行 ./update-sources.sh"$'\n'"$UPDATES"
  CODE=10
else
  BODY="UPTODATE 全部最新，无需运行 update-sources.sh"$'\n'
  CODE=0
fi
[ -n "$ERRORS" ] && BODY="${BODY}${ERRORS}"
# 即使错误优先决定退出码，也保留已成功探测到的更新，方便用户下一步处理。
[ -n "$ERRORS" ] && [ -n "$UPDATES" ] && BODY="${BODY}UPDATE 同时发现以下更新（修复检查错误后再执行 update-sources.sh）"$'\n'"$UPDATES"
# notice 一定要显示（它要人工处理），但不改变退出码，不驱使 agent 跑 update-sources.sh
[ -n "$NOTICES" ] && BODY="${BODY}NOTICE 以下需人工处理，跑 update-sources.sh 也不会变"$'\n'"${NOTICES}"
[ "$VERBOSE" -eq 1 ] && [ -n "$OKS" ] && BODY="${BODY}${OKS}"
if [ "$VERBOSE" -eq 1 ]; then
  BODY="${BODY}（${#FRESH[@]} 项走网络，其余取自 ${TTL}s 缓存；-f 强制全部重查）"$'\n'
fi

printf '%s' "$BODY"
exit "$CODE"
