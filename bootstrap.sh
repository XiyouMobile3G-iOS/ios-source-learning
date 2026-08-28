#!/bin/bash
#
# bootstrap.sh —— 一键把「源码学习」工作区搭起来（下载源码 + 挂载源码地图）
#
#   ./bootstrap.sh                 下载缺失的上游源码 + 挂载源码地图（可重复运行）
#   ./bootstrap.sh -n              演练，只报告不改动
#   ./bootstrap.sh --maps-only     只重新挂载地图，不下载（旧名 --notes-only 仍可用）
#   ./bootstrap.sh --check         只体检：本地有什么、缺什么、链接是否完好，不改动
#   ./bootstrap.sh objc4 cf        只处理指定目标
#   ./bootstrap.sh -h              帮助
#
# 目标见 sources.sh；当前为
#   Apple 底层：objc4 / libdispatch / libdispatch-apple / foundation / swift-foundation / cf
#   参照实现：  gnustep（gnustep-base，非 Apple 代码）
#   第三方库：  afnetworking / jsonmodel / sdwebimage（下载到 third-party/）
#
# 三件事，跑之前先知道：
#
# 1. 源码不进本仓库。本仓库只版本管理源码地图与脚本；十份源码由本脚本从各自上游
#    下载到固定 ref，并由 .gitignore 忽略——脚本每轮都会用 git check-ignore
#    核对这一点，漏了会告警。
#
# 2. 下载前先核对本地。已经下载过的不会重复拉（首次 2–3 GB），同时核对
#    origin 与当前版本：目录里放着别的仓库、或版本与地图基准不一致，都会明确
#    报出来并给出对齐命令，但**绝不自动切版本**——切了地图里的行号就全废了。
#
# 3. 地图的真身在 maps/，以符号链接挂回源码树原位，所以「就地编辑」改的
#    仍然是被版本管理的那份文件，不会漂移。
#
# 源码清单在同目录的 sources.sh，与 check-updates.sh / update-sources.sh 共用。
# 下载进度条在 progress.sh，clone / fetch 共用。
#
# 搭好之后的日常循环见 README.md：check-updates.sh → update-sources.sh。
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
MAPS_ONLY=0
CHECK_ONLY=0

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

FAILED=0
SUMMARY=""
note() { SUMMARY="${SUMMARY}$1\n"; }

run() {
  if [ "$DRY_RUN" -eq 1 ] || [ "$CHECK_ONLY" -eq 1 ]; then
    info "[dry-run] $*"
    return 0
  fi
  "$@"
}

usage() {
  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"
  exit 0
}

# ── 源码清单 ────────────────────────────────────────────────────────────
# 清单是三个脚本共用的单一事实来源，新增源码只改 sources.sh 一行。
if [ ! -f "$ROOT/sources.sh" ]; then
  printf '缺少 sources.sh（源码清单），无法继续\n' >&2
  exit 1
fi
# shellcheck source=sources.sh
. "$ROOT/sources.sh"
# shellcheck source=progress.sh
. "$ROOT/progress.sh"

# ── 参数解析 ────────────────────────────────────────────────────────────
TARGETS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run)  DRY_RUN=1 ;;
    --maps-only)   MAPS_ONLY=1 ;;
    --notes-only)  MAPS_ONLY=1 ;;   # 旧名，maps/ 改名前的写法，保留兼容
    --check)       CHECK_ONLY=1 ;;
    -h|--help)     usage ;;
    -*)            err "未知参数 $1"; exit 1 ;;
    *)             TARGETS+=("$1") ;;
  esac
  shift
done

ALL_TARGETS=()
while IFS= read -r key; do ALL_TARGETS+=("$key"); done < <(source_all_keys)
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=("${ALL_TARGETS[@]}")

# 目标名打错时早点报错，别等跑完才发现什么都没做
for t in "${TARGETS[@]}"; do
  source_lookup "$t" || { err "未知目标 ${t}（可用：${ALL_TARGETS[*]}）"; exit 1; }
done

wants() {
  local t
  for t in "${TARGETS[@]}"; do [ "$t" = "$1" ] && return 0; done
  return 1
}

# ── 下载前的本地核对 ────────────────────────────────────────────────────
# 已经下载过的源码不重复拉（首次 2–3 GB，重下一次代价太大），
# 但「目录在」不等于「源码对」——还要核对 origin 与版本，否则后面地图的行号会对不上。
#
# 返回：0 本地已有可用源码，跳过下载   1 本地没有，需要下载   2 有冲突，需人工处理
inspect_local() {
  local key="$1" dir="$2" url="$3" policy="$4" ref="$5"
  local path="$ROOT/$dir"

  if source_needs_clone "$dir"; then
    return 1
  fi
  source_local_state "$dir"
  case $? in
    2)
      err "$dir 已存在但不是 git 仓库，未覆盖，请先手动移走"
      note "  ${key}  ${C_RED}目录冲突${C_RESET}"
      FAILED=1
      return 2
      ;;
  esac

  local desc actual_url
  desc="$(git -C "$path" describe --tags --always 2>/dev/null || echo '?')"
  actual_url="$(git -C "$path" config --get remote.origin.url 2>/dev/null || true)"

  # 来源核对：同名目录里放着别的仓库，比缺源码更难排查，一律不动它
  if [ -n "$actual_url" ] && \
     [ "$(source_norm_url "$actual_url")" != "$(source_norm_url "$url")" ]; then
    err "$dir 已存在，但 origin 指向别的仓库"
    info "当前：$actual_url"
    info "期望：$url"
    info "确认要重来：先移走该目录，再跑一次本脚本"
    note "  ${key}  ${C_RED}来源不符${C_RESET}"
    FAILED=1
    return 2
  fi

  # 版本核对：只报告，绝不自动切换——切版本会让地图里的行号全部失效
  case "$policy" in
    pinned)
      local want_sha
      want_sha="$(git -C "$path" rev-parse --verify --quiet "refs/tags/${ref}^{commit}" 2>/dev/null || true)"
      if [ -n "$want_sha" ] && [ "$(git -C "$path" rev-parse HEAD 2>/dev/null)" = "$want_sha" ]; then
        ok "本地已有源码，版本正确（${ref}）"
        note "  ${key}  已有（${ref}）"
      else
        warn "本地已有源码，但当前是 ${desc}，地图基准是 ${ref}"
        info "要对齐：git -C \"${dir}\" checkout -B ${ref} refs/tags/${ref}"
        note "  ${key}  ${C_YELLOW}版本不符${C_RESET}（${desc} ≠ ${ref}）"
      fi
      ;;
    track)
      local branch
      branch="$(git -C "$path" symbolic-ref --short -q HEAD 2>/dev/null || true)"
      if [ "$branch" = "$ref" ]; then
        ok "本地已有源码，在分支 ${ref}（${desc}）"
        note "  ${key}  已有（${ref}@${desc}）"
      else
        warn "本地已有源码，但在 ${branch:-游离 HEAD} 上，期望分支 ${ref}"
        info "要对齐：git -C \"${dir}\" checkout ${ref}"
        note "  ${key}  ${C_YELLOW}分支不符${C_RESET}（${branch:-detached}）"
      fi
      ;;
    *)
      ok "本地已有源码（${desc}）"
      note "  ${key}  已有（${desc}）"
      ;;
  esac
  return 0
}

# ── 确认源码不会被本仓库跟踪 ────────────────────────────────────────────
# 源码体量 2–3 GB，一旦漏进 .gitignore 被 add 进来，本仓库就废了。
check_ignored() {
  local dir="$1"
  git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || return 0   # 不是 git 仓库就不必查
  git -C "$ROOT" check-ignore -q "$dir" 2>/dev/null && return 0
  warn "$dir 未被 .gitignore 忽略，有被误提交进本仓库的风险"
  info "请在 .gitignore 补一行：/${dir}/"
  return 1
}

# ── 下载 ────────────────────────────────────────────────────────────────
clone_repo() {
  local key="$1" dir="$2" url="$3" policy="$4" ref="$5" filter="$6" tagglob="${7:-}"
  local path="$ROOT/$dir"

  info "下载 $(source_redact_url "$url")"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[dry-run] git clone ${filter:+$filter }--progress $(source_redact_url "$url") $path"
    note "  ${key}  [dry-run] 待下载"
    return 0
  fi
  # 终端画总进度条；非终端走 git --progress 自己的百分比行。
  # 有无 --filter 合成一次调用，与上面 dry-run 那行同一套 ${filter:+...}。
  git_run_progress "$key" "$CLONE_DONE" "$CLONE_TOTAL" \
    git clone ${filter:+$filter }--progress "$url" "$path" \
    || { err "下载失败"; note "  ${key}  ${C_RED}下载失败${C_RESET}"; FAILED=1; return 1; }
  CLONE_DONE=$((CLONE_DONE + 1))

  case "$policy" in
    pinned)
      # 用 refs/tags/ 全名，避开同名远端分支造成的歧义
      if run git -C "$path" checkout --quiet -B "$ref" "refs/tags/$ref"; then
        ok "已钉到 ${ref}（本地分支 ${ref}）"
      else
        err "checkout tag $ref 失败"; FAILED=1; return 1
      fi
      ;;
    latest)
      local tag
      tag="$(git -C "$path" tag --list ${tagglob:+"$tagglob"} --sort=-v:refname | head -1)"
      if [ -n "$tag" ] && run git -C "$path" checkout --quiet "$tag"; then
        ok "已切到最新 drop ${tag}（detached HEAD，符合预期）"
      else
        err "切最新 tag 失败"; FAILED=1; return 1
      fi
      ;;
    track)
      run git -C "$path" checkout --quiet "$ref" 2>/dev/null
      ok "在分支 $ref"
      ;;
  esac
  note "  ${key}  ${C_GREEN}已下载${C_RESET}"
  return 0
}

# ── .git/info/exclude ───────────────────────────────────────────────────
# 让挂进来的地图不出现在子仓库的 git status 里：否则工作区被判为「脏」，
# update-sources.sh 会按安全策略跳过合并，更新机制就静默失效了。
write_exclude() {
  local dir="$1" path="$ROOT/$1" file="$ROOT/$1/.git/info/exclude"
  [ -d "$path/.git" ] || return 0

  local lines=("AGENTS.md" "CLAUDE.md")
  [ "$dir" = "new objc4" ] && lines+=("objc.xcodeproj/xcuserdata/" "objc.xcodeproj/project.xcworkspace/")

  local missing=() l
  for l in "${lines[@]}"; do
    grep -qxF "$l" "$file" 2>/dev/null || missing+=("$l")
  done
  [ ${#missing[@]} -eq 0 ] && return 0

  if [ "$DRY_RUN" -eq 1 ] || [ "$CHECK_ONLY" -eq 1 ]; then
    info "[dry-run] 追加 exclude 规则：${missing[*]}"
    return 0
  fi
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "${missing[@]}" >> "$file"
  ok "已补 .git/info/exclude 规则：${missing[*]}"
}

# ── 挂载源码地图 ────────────────────────────────────────────────────────
# 计算从 <链接所在目录，相对工作区根> 回到工作区根的相对前缀，保证符号链接
# 与工作区一起搬家/改名后依然有效（绝对路径链接做不到这点）。
# 传入的必须是相对根的完整路径（如 third-party/AFNetworking/Cache），
# 只数仓库内深度会漏掉 third-party/ 这类中间层。
rel_prefix() {
  local dir="$1" up="" part
  [ "$dir" = "." ] && { printf ''; return; }
  local oldifs="$IFS"; IFS='/'
  for part in $dir; do up="../$up"; done
  IFS="$oldifs"
  printf '%s' "$up"
}

link_maps() {
  local dir="$1" src_root="$ROOT/maps/$1"
  local linked=0 broken=0 skipped=0

  [ -d "$src_root" ] || { warn "maps/$dir 不存在，跳过"; return 0; }
  if [ ! -d "$ROOT/$dir/.git" ]; then
    warn "$dir 尚未克隆，地图暂不挂载"
    note "  ${dir}  ${C_YELLOW}地图未挂载${C_RESET}（源码未克隆）"
    return 0
  fi

  local f rel target link linkdir linkrel
  while IFS= read -r f; do
    rel="${f#"$src_root"/}"                    # 例：runtime/AGENTS.md
    link="$ROOT/$dir/$rel"
    linkdir="$(dirname "$rel")"
    linkrel="$dir"                             # 链接所在目录，相对工作区根
    [ "$linkdir" != "." ] && linkrel="$dir/$linkdir"
    target="$(rel_prefix "$linkrel")maps/$dir/$rel"

    if [ -L "$link" ]; then
      if [ "$(readlink "$link")" = "$target" ] && [ -e "$link" ]; then
        linked=$((linked + 1)); continue
      fi
      run rm -f "$link"
    elif [ -e "$link" ]; then
      # 上游哪天自己加了同名文件，或用户手写过一份——不覆盖，交人工判断
      err "$dir/$rel 已存在且不是本仓库的链接，未覆盖"
      skipped=$((skipped + 1)); FAILED=1; continue
    fi

    if [ "$CHECK_ONLY" -eq 1 ]; then
      warn "缺链接：$dir/$rel"
      broken=$((broken + 1)); continue
    fi
    run mkdir -p "$(dirname "$link")"
    if run ln -s "$target" "$link"; then
      linked=$((linked + 1))
    else
      err "创建链接失败：$dir/$rel"; broken=$((broken + 1)); FAILED=1
    fi
  done < <(find "$src_root" -type f -name '*.md' | sort)

  if [ "$broken" -eq 0 ] && [ "$skipped" -eq 0 ]; then
    ok "地图已就位（${linked} 个链接）"
    note "  ${dir}  地图 ${linked} 份"
  else
    warn "地图 ${linked} 个正常，${broken} 个缺失/失败，${skipped} 个被占用"
    note "  ${dir}  ${C_YELLOW}地图 ${linked}/$((linked + broken + skipped))${C_RESET}"
  fi
}

# 先数要下几个。TARGETS 就是 wants 从 ALL_TARGETS 筛出来的那批，
# 谓词与 inspect_local 相同（source_needs_clone），所以和实际 clone 次数对齐。
CLONE_TOTAL=0
CLONE_DONE=0
if [ "$MAPS_ONLY" -eq 0 ] && [ "$CHECK_ONLY" -eq 0 ]; then
  CLONE_TOTAL=$(source_count source_needs_clone "${TARGETS[@]}")
fi

# ── 主流程 ──────────────────────────────────────────────────────────────
printf '%s源码学习工作区初始化%s  %s\n' "$C_BOLD" "$C_RESET" "$ROOT"
[ "$DRY_RUN" -eq 1 ]    && warn "dry-run 模式，不会做任何改动"
[ "$CHECK_ONLY" -eq 1 ] && warn "check 模式，只体检不改动"
[ "$MAPS_ONLY" -eq 1 ] && warn "只挂地图，不克隆源码"
[ "$CLONE_TOTAL" -gt 0 ] && info "将下载 ${CLONE_TOTAL} 个仓库（终端下显示进度条）"

for key in "${ALL_TARGETS[@]}"; do
  wants "$key" || continue
  source_lookup "$key" || continue

  hdr "${SRC_KEY}（${SRC_DIR}）"

  # 先核对本地：已有就不重复下载，缺了才下载
  inspect_local "$SRC_KEY" "$SRC_DIR" "$SRC_URL" "$SRC_POLICY" "$SRC_REF"
  case $? in
    2) continue ;;                       # 目录冲突 / 来源不符，人工处理
    1)
      if [ "$MAPS_ONLY" -eq 1 ] || [ "$CHECK_ONLY" -eq 1 ]; then
        warn "本地没有源码（去掉 --maps-only / --check 即可下载）"
        note "  ${SRC_KEY}  ${C_YELLOW}缺源码${C_RESET}"
      else
        clone_repo "$SRC_KEY" "$SRC_DIR" "$SRC_URL" "$SRC_POLICY" "$SRC_REF" "$SRC_FILTER" "$SRC_TAGGLOB" || continue
      fi
      ;;
  esac

  check_ignored "$SRC_DIR"
  write_exclude "$SRC_DIR"
  link_maps "$SRC_DIR"
done

printf '\n%s摘要%s\n' "$C_BOLD" "$C_RESET"
printf "$SUMMARY"

if [ "$FAILED" -eq 0 ] && [ "$CHECK_ONLY" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
  printf '\n下一步：%s./check-updates.sh -v%s 确认版本，然后把问题丢给 agent，它会读 AGENTS.md 自己找路。\n' "$C_BOLD" "$C_RESET"
fi
printf '\n'
exit "$FAILED"
