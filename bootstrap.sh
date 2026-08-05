#!/bin/bash
#
# bootstrap.sh —— 一键把「源码学习」工作区搭起来
#
#   ./bootstrap.sh                 克隆缺失的上游源码 + 挂载笔记（可重复运行）
#   ./bootstrap.sh -n              演练，只报告不改动
#   ./bootstrap.sh --notes-only    只重新挂载笔记，不克隆
#   ./bootstrap.sh --check         只体检：报告缺什么、链接是否完好，不改动
#   ./bootstrap.sh objc4 cf        只处理指定目标
#   ./bootstrap.sh -h              帮助
#
# 目标：objc4 / libdispatch / libdispatch-apple / foundation / cf
#
# 本仓库只版本管理笔记与脚本，五份 Apple 源码由本脚本从各自上游克隆到
# 固定 ref；notes/ 下的笔记以符号链接挂回源码树原位，因此「就地编辑笔记」
# 改的仍然是被版本管理的那份文件，不会漂移。
#
# 搭好之后的日常循环见 README.md：check-updates.sh → update-sources.sh。
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
NOTES_ONLY=0
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

# ── 仓库定义 ────────────────────────────────────────────────────────────
# 目标名|目录名|上游 URL|模式|ref
#   模式 branch      追踪该分支（日常 ff-only 更新）
#   模式 pinned-tag  钉在指定 tag 上并建同名本地分支（笔记行号按此 drop 写）
#   模式 latest-tag  切到版本号最高的 tag（Apple drop 代码在 tag 上，main 常落后）
# blob:none 部分克隆用于两个体量大、只读研究的 Swift 仓库。
REPOS=(
  "objc4|new objc4|https://github.com/apple-oss-distributions/objc4.git|pinned-tag|objc4-951.7|"
  "libdispatch|libdispatch|https://github.com/apple/swift-corelibs-libdispatch.git|branch|main|--filter=blob:none"
  "libdispatch-apple|libdispatch-apple|https://github.com/apple-oss-distributions/libdispatch.git|latest-tag||"
  "foundation|swift-corelibs-foundation|https://github.com/apple/swift-corelibs-foundation.git|branch|main|--filter=blob:none"
  "cf|CF-1153.18-apple|https://github.com/apple-oss-distributions/CF.git|branch|main|"
)

# ── 参数解析 ────────────────────────────────────────────────────────────
TARGETS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run)  DRY_RUN=1 ;;
    --notes-only)  NOTES_ONLY=1 ;;
    --check)       CHECK_ONLY=1 ;;
    -h|--help)     usage ;;
    -*)            err "未知参数 $1"; exit 1 ;;
    *)             TARGETS+=("$1") ;;
  esac
  shift
done

ALL_TARGETS=()
for spec in "${REPOS[@]}"; do
  IFS='|' read -r key _ _ _ _ _ <<< "$spec"
  ALL_TARGETS+=("$key")
done
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=("${ALL_TARGETS[@]}")

wants() {
  local t
  for t in "${TARGETS[@]}"; do [ "$t" = "$1" ] && return 0; done
  return 1
}

# ── 克隆 ────────────────────────────────────────────────────────────────
clone_repo() {
  local key="$1" dir="$2" url="$3" mode="$4" ref="$5" filter="$6"
  local path="$ROOT/$dir"

  if [ -d "$path/.git" ]; then
    local desc
    desc="$(git -C "$path" describe --tags --always 2>/dev/null || echo '?')"
    ok "已存在，跳过克隆（${desc}）"
    note "  ${key}  已存在"
    return 0
  fi

  if [ -e "$path" ]; then
    err "$dir 已存在但不是 git 仓库，请先手动移走"
    note "  ${key}  ${C_RED}目录冲突${C_RESET}"
    FAILED=1
    return 1
  fi

  info "克隆 $url"
  if [ -n "$filter" ]; then
    run git clone $filter --quiet "$url" "$path" || { err "克隆失败"; note "  ${key}  ${C_RED}克隆失败${C_RESET}"; FAILED=1; return 1; }
  else
    run git clone --quiet "$url" "$path" || { err "克隆失败"; note "  ${key}  ${C_RED}克隆失败${C_RESET}"; FAILED=1; return 1; }
  fi
  [ "$DRY_RUN" -eq 1 ] && { note "  ${key}  [dry-run] 待克隆"; return 0; }

  case "$mode" in
    pinned-tag)
      # 用 refs/tags/ 全名，避开同名远端分支造成的歧义
      if run git -C "$path" checkout --quiet -B "$ref" "refs/tags/$ref"; then
        ok "已钉到 drop ${ref}（本地分支 ${ref}）"
      else
        err "checkout tag $ref 失败"; FAILED=1; return 1
      fi
      ;;
    latest-tag)
      local tag
      tag="$(git -C "$path" tag --sort=-v:refname | head -1)"
      if [ -n "$tag" ] && run git -C "$path" checkout --quiet "$tag"; then
        ok "已切到最新 drop ${tag}（detached HEAD，符合预期）"
      else
        err "切最新 tag 失败"; FAILED=1; return 1
      fi
      ;;
    branch)
      run git -C "$path" checkout --quiet "$ref" 2>/dev/null
      ok "在分支 $ref"
      ;;
  esac
  note "  ${key}  ${C_GREEN}已克隆${C_RESET}"
  return 0
}

# ── .git/info/exclude ───────────────────────────────────────────────────
# 让挂进来的笔记不出现在子仓库的 git status 里：否则工作区被判为「脏」，
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

# ── 挂载笔记 ────────────────────────────────────────────────────────────
# 计算从 <链接所在目录> 回到工作区根的相对前缀，保证符号链接与工作区
# 一起搬家/改名后依然有效（绝对路径链接做不到这点）。
rel_prefix() {
  local dir="$1" up="" part
  [ "$dir" = "." ] && { printf ''; return; }
  local oldifs="$IFS"; IFS='/'
  for part in $dir; do up="../$up"; done
  IFS="$oldifs"
  printf '%s' "$up"
}

link_notes() {
  local dir="$1" src_root="$ROOT/notes/$1"
  local linked=0 broken=0 skipped=0

  [ -d "$src_root" ] || { warn "notes/$dir 不存在，跳过"; return 0; }
  if [ ! -d "$ROOT/$dir/.git" ]; then
    warn "$dir 尚未克隆，笔记暂不挂载"
    note "  ${dir}  ${C_YELLOW}笔记未挂载${C_RESET}（源码未克隆）"
    return 0
  fi

  local f rel target link linkdir
  while IFS= read -r f; do
    rel="${f#"$src_root"/}"                    # 例：runtime/CLAUDE.md
    link="$ROOT/$dir/$rel"
    linkdir="$(dirname "$rel")"
    target="$(rel_prefix "$linkdir")../notes/$dir/$rel"

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
    ok "笔记已就位（${linked} 个链接）"
    note "  ${dir}  笔记 ${linked} 份"
  else
    warn "笔记 ${linked} 个正常，${broken} 个缺失/失败，${skipped} 个被占用"
    note "  ${dir}  ${C_YELLOW}笔记 ${linked}/$((linked + broken + skipped))${C_RESET}"
  fi
}

# ── 主流程 ──────────────────────────────────────────────────────────────
printf '%s源码学习工作区初始化%s  %s\n' "$C_BOLD" "$C_RESET" "$ROOT"
[ "$DRY_RUN" -eq 1 ]    && warn "dry-run 模式，不会做任何改动"
[ "$CHECK_ONLY" -eq 1 ] && warn "check 模式，只体检不改动"
[ "$NOTES_ONLY" -eq 1 ] && warn "只挂笔记，不克隆源码"

for spec in "${REPOS[@]}"; do
  IFS='|' read -r key dir url mode ref filter <<< "$spec"
  wants "$key" || continue

  hdr "${key}（${dir}）"
  if [ "$NOTES_ONLY" -eq 0 ] && [ "$CHECK_ONLY" -eq 0 ]; then
    clone_repo "$key" "$dir" "$url" "$mode" "$ref" "$filter" || continue
  elif [ ! -d "$ROOT/$dir/.git" ]; then
    warn "$dir 未克隆（去掉 --notes-only / --check 即可克隆）"
  fi
  write_exclude "$dir"
  link_notes "$dir"
done

printf '\n%s摘要%s\n' "$C_BOLD" "$C_RESET"
printf "$SUMMARY"

if [ "$FAILED" -eq 0 ] && [ "$CHECK_ONLY" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
  printf '\n下一步：%s./check-updates.sh -v%s 确认版本，然后把问题丢给 agent，它会读 AGENTS.md 自己找路。\n' "$C_BOLD" "$C_RESET"
fi
printf '\n'
exit "$FAILED"
