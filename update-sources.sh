#!/bin/bash
#
# update-sources.sh —— 更新「源码学习」工作区里的全部源码仓库
#
#   ./update-sources.sh          更新全部
#   ./update-sources.sh -n       演练，只报告不改动
#   ./update-sources.sh -f       允许对脏工作区的仓库执行 stash + 更新
#   ./update-sources.sh libdispatch foundation    只更新指定目标
#   ./update-sources.sh -h       帮助
#
# 目标（Apple 底层）：objc4 / libdispatch / libdispatch-apple / foundation / swift-foundation / cf
# 目标（参照实现）：  gnustep
# 目标（第三方库）：  afnetworking / jsonmodel / sdwebimage
# 目标清单与各自的更新策略都在同目录的 sources.sh，三个脚本共用。
# 本脚本只更新**已经下载过**的源码；没下载的会提示去跑 bootstrap.sh，不会顺手替你下。
#
# 想先知道「到底需不需要更新」，用同目录的 ./check-updates.sh
# （只读远端、不改工作区、输出一行、带缓存）。
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 源码清单：与 bootstrap.sh / check-updates.sh 共用的单一事实来源
if [ ! -f "$ROOT/sources.sh" ]; then
  printf '缺少 sources.sh（源码清单），无法继续\n' >&2
  exit 1
fi
# shellcheck source=sources.sh
. "$ROOT/sources.sh"
# shellcheck source=progress.sh
. "$ROOT/progress.sh"

DRY_RUN=0
FORCE=0
RETRIES=3      # 网络抖动时 fetch 的重试次数
RETRY_WAIT=3   # 每次重试前等待秒数

# ── 输出 ────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
fi

hdr()  { printf '\n%s▸ %s%s\n' "$C_BOLD$C_BLUE" "$*" "$C_RESET"; }
ok()   { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*"; }
info() { printf '  %s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }

SUMMARY=""
note() { SUMMARY="${SUMMARY}$1\n"; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[dry-run] $*"
    return 0
  fi
  "$@"
}

usage() {
  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"
  exit 0
}

# ── 通用 git 更新 ───────────────────────────────────────────────────────
# $1 目录名  $2 显示名  $3 模式：
#   pull（默认）  fetch 后对 tracking 分支做 merge --ff-only
#   fetch-only    只 fetch 并报告有无新 tag，永不动工作区（用于 objc4、gnustep 与三份第三方库）
#   latest-tag    fetch 后自动 checkout 到版本号最高的 tag（用于 Apple drop 仓库）
# $4 tag 过滤 glob（可空）：只在 fetch-only / latest-tag 下用，见 sources.sh
update_git_repo() {
  local dir="$ROOT/$1" name="$2" mode="${3:-pull}" tagglob="${4:-}"

  if [ ! -d "${dir}/.git" ]; then
    err "${name}: $1 不是 git 仓库，跳过"
    note "  ${name}  跳过（非 git 仓库）"
    return
  fi

  local before branch dirty upstream behind ahead
  before="$(git -C "${dir}" rev-parse --short HEAD 2>/dev/null)"
  branch="$(git -C "${dir}" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  dirty="$(git -C "${dir}" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

  info "分支 ${branch} @ ${before}，未提交改动 ${dirty} 处"

  local attempt=1 fetched=0
  while [ ${attempt} -le "$RETRIES" ]; do
    if [ "$DRY_RUN" -eq 1 ]; then
      info "[dry-run] git fetch --all --tags --prune --progress"
      fetched=1
      break
    fi
    if git_run_progress "$name" "$FETCH_DONE" "$FETCH_TOTAL" \
         git -C "${dir}" fetch --all --tags --prune --progress; then
      fetched=1
      break
    fi
    [ ${attempt} -lt "$RETRIES" ] && warn "fetch 第 ${attempt} 次失败，${RETRY_WAIT}s 后重试" && sleep "$RETRY_WAIT"
    attempt=$((attempt + 1))
  done
  FETCH_DONE=$((FETCH_DONE + 1))
  if [ ${fetched} -ne 1 ]; then
    err "${name}: fetch 连续 $RETRIES 次失败（网络？SSH key？）"
    note "  ${name}  ${C_RED}fetch 失败${C_RESET}"
    return
  fi
  ok "已 fetch 远端 + tags"

  # objc4 这类「自建分支 + 本地地图」的仓库只报告，不动工作区
  if [ "${mode}" = "fetch-only" ]; then
    local latest_tag
    latest_tag="$(git -C "${dir}" tag --list ${tagglob:+"$tagglob"} --sort=-v:refname 2>/dev/null | head -1)"
    [ -n "${latest_tag}" ] && info "远端最新 tag: ${latest_tag}"
    if [ -n "${latest_tag}" ] && ! git -C "${dir}" merge-base --is-ancestor "${latest_tag}" HEAD 2>/dev/null; then
      warn "有更新的版本（${latest_tag}）未合入当前分支"
      note "  ${name}  ${C_YELLOW}发现新版本 ${latest_tag}${C_RESET}（需手动 checkout / rebase）"
    else
      ok "已是最新版本"
      note "  ${name}  已最新（${branch} @ ${before}）"
    fi
    return
  fi

  # Apple drop 仓库：代码在 tag 上（main 常落后于最新 tag），追最新 tag 而非分支
  if [ "${mode}" = "latest-tag" ]; then
    local latest_tag tag_sha
    # 本模式会自动 checkout，比 fetch-only 更依赖 tagglob：漏过滤会静默把源码树
    # 切到非版本号的历史 tag，该仓库地图里的行号全部失效。与 bootstrap.sh 的
    # latest 分支保持同一套过滤。
    latest_tag="$(git -C "${dir}" tag --list ${tagglob:+"$tagglob"} --sort=-v:refname 2>/dev/null | head -1)"
    if [ -z "${latest_tag}" ]; then
      warn "没有 tag，退化为只 fetch"
      note "  ${name}  仅 fetch（无 tag）"
      return
    fi
    tag_sha="$(git -C "${dir}" rev-parse --short "${latest_tag}^{commit}" 2>/dev/null)"
    info "远端最新 drop: ${latest_tag}（${tag_sha}）"

    if [ "${before}" = "${tag_sha}" ]; then
      ok "已在最新 drop ${latest_tag}"
      note "  ${name}  已最新（${latest_tag}）"
      return
    fi
    if [ "${dirty}" -gt 0 ] && [ "$FORCE" -ne 1 ]; then
      warn "工作区有 ${dirty} 处改动，不自动切 tag（加 -f 可自动 stash）"
      note "  ${name}  ${C_YELLOW}跳过${C_RESET}（工作区脏，新 drop ${latest_tag} 未切）"
      return
    fi
    [ "${dirty}" -gt 0 ] && run git -C "${dir}" stash push -u -m "update-sources.sh auto-stash" >/dev/null
    if run git -C "${dir}" checkout --quiet "${latest_tag}"; then
      ok "已切到新 drop ${latest_tag}（${before} → ${tag_sha}）"
      note "  ${name}  ${C_GREEN}新 drop${C_RESET} ${latest_tag}（${before} → ${tag_sha}）"
    else
      err "checkout ${latest_tag} 失败"
      note "  ${name}  ${C_RED}checkout 失败${C_RESET}"
    fi
    [ "${dirty}" -gt 0 ] && run git -C "${dir}" stash pop >/dev/null
    return
  fi

  upstream="$(git -C "${dir}" rev-parse --abbrev-ref '@{u}' 2>/dev/null)"
  if [ -z "${upstream}" ]; then
    warn "分支 ${branch} 没有上游，只 fetch 不合并"
    note "  ${name}  仅 fetch（无上游分支）"
    return
  fi

  behind="$(git -C "${dir}" rev-list --count "HEAD..@{u}" 2>/dev/null || echo 0)"
  ahead="$(git -C "${dir}" rev-list --count "@{u}..HEAD" 2>/dev/null || echo 0)"

  if [ "${behind}" -eq 0 ]; then
    ok "已是最新（与 ${upstream} 同步）"
    note "  ${name}  已最新（${before}）"
    return
  fi

  info "落后 ${upstream} ${behind} 个提交，领先 ${ahead} 个"

  if [ "${ahead}" -gt 0 ]; then
    warn "本地有 ${ahead} 个未推送提交，不做 ff-only 合并，请手动 rebase"
    note "  ${name}  ${C_YELLOW}分叉${C_RESET}（落后 ${behind} / 领先 ${ahead}），需手动处理"
    return
  fi

  local stashed=0
  if [ "${dirty}" -gt 0 ]; then
    if [ "$FORCE" -eq 1 ]; then
      warn "工作区有 ${dirty} 处改动，先 stash"
      run git -C "${dir}" stash push -u -m "update-sources.sh auto-stash" >/dev/null && stashed=1
    else
      warn "工作区有 ${dirty} 处改动，跳过合并（加 -f 可自动 stash）"
      note "  ${name}  ${C_YELLOW}跳过${C_RESET}（工作区脏，落后 ${behind} 个提交）"
      return
    fi
  fi

  if run git -C "${dir}" merge --ff-only "@{u}" --quiet; then
    local after
    after="$(git -C "${dir}" rev-parse --short HEAD 2>/dev/null)"
    ok "已更新 ${before} → ${after}（+${behind} 提交）"
    note "  ${name}  ${C_GREEN}已更新${C_RESET} ${before} → ${after}（+${behind}）"
  else
    err "ff-only 合并失败"
    note "  ${name}  ${C_RED}合并失败${C_RESET}"
  fi

  if [ "${stashed}" -eq 1 ]; then
    run git -C "${dir}" stash pop >/dev/null && ok "已恢复 stash" || err "stash pop 失败，用 git stash list 手动处理"
  fi
}

# ── 参数解析 ────────────────────────────────────────────────────────────
TARGETS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    -f|--force)   FORCE=1 ;;
    -h|--help)    usage ;;
    -*)           err "未知参数 $1"; exit 1 ;;
    *)            TARGETS+=("$1") ;;
  esac
  shift
done

ALL_TARGETS=()
while IFS= read -r k; do ALL_TARGETS+=("$k"); done < <(source_all_keys)
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=("${ALL_TARGETS[@]}")

wants() {
  local t
  for t in "${TARGETS[@]}"; do [ "$t" = "$1" ] && return 0; done
  return 1
}

for t in "${TARGETS[@]}"; do
  source_lookup "$t" || { err "未知目标 ${t}（可用：${ALL_TARGETS[*]}）"; exit 1; }
done

# 先数本次能 fetch 几个，进度条才能把「第几个仓库」叠进总百分比
FETCH_TOTAL=$(source_count source_has_repo "${TARGETS[@]}")
FETCH_DONE=0

# ── 主流程 ──────────────────────────────────────────────────────────────
printf '%s源码学习工作区更新%s  %s\n' "$C_BOLD" "$C_RESET" "$ROOT"
[ "$DRY_RUN" -eq 1 ] && warn "dry-run 模式，不会做任何改动"
[ "$FETCH_TOTAL" -gt 0 ] && info "将 fetch ${FETCH_TOTAL} 个仓库（终端下显示进度条）"

# 清单里的策略在这里翻译成更新模式：
#   pinned → fetch-only  钉住的 tag，只 fetch 报告新版本，永不动工作区
#   track  → pull        追踪分支，merge --ff-only
#   latest → latest-tag  自动 checkout 到版本号最高的 tag
for key in "${ALL_TARGETS[@]}"; do
  wants "$key" || continue
  source_lookup "$key" || continue

  case "$SRC_POLICY" in
    pinned) mode=fetch-only ;;
    latest) mode=latest-tag ;;
    *)      mode=pull ;;
  esac

  hdr "${SRC_NAME}（$(source_policy_desc "$SRC_POLICY")）"

  # 本地核对：没下载过就别 fetch，直接告诉用户去 bootstrap
  if [ ! -d "$ROOT/$SRC_DIR/.git" ]; then
    if [ -e "$ROOT/$SRC_DIR" ]; then
      err "${SRC_DIR} 存在但不是 git 仓库，先移走再跑 ./bootstrap.sh ${SRC_KEY}"
      note "  ${SRC_NAME}  ${C_RED}目录冲突${C_RESET}"
    else
      warn "本地没有源码，先跑 ./bootstrap.sh ${SRC_KEY} 下载"
      note "  ${SRC_NAME}  ${C_YELLOW}缺源码${C_RESET}"
    fi
    continue
  fi

  update_git_repo "$SRC_DIR" "$SRC_NAME" "$mode" "$SRC_TAGGLOB"
done

# 本次动过的目标，其 check-updates.sh 缓存作废；没动过的保留，
# 免得只更新一个目标却把其余四个的缓存一起废掉、下次白跑一趟网络
if [ "$DRY_RUN" -eq 0 ] && [ -d "$ROOT/.update-check-cache" ]; then
  cleared=""
  for t in "${TARGETS[@]}"; do
    [ -e "$ROOT/.update-check-cache/$t" ] || continue
    rm -f "$ROOT/.update-check-cache/$t" && cleared="${cleared}${t} "
  done
  rmdir "$ROOT/.update-check-cache" 2>/dev/null
  [ -n "$cleared" ] && info "已作废 check-updates.sh 缓存：${cleared% }"
fi

printf '\n%s摘要%s\n' "$C_BOLD" "$C_RESET"
printf "$SUMMARY"
printf '\n'
