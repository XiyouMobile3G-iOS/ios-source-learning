#!/bin/bash
#
# sources.sh —— 源码清单：bootstrap.sh / check-updates.sh / update-sources.sh 的**唯一事实来源**
#
# 这个文件本身不做任何事，只被上面三个脚本 `source` 进去。
# 新增或调整一份源码，**只改这里一行**，三个脚本自动同步；
# 以前清单抄在三个脚本里，改一处漏两处是最常见的故障。
#
# 字段：目标名|目录名|显示名|上游 URL|策略|ref|clone 附加参数|tag 过滤 glob
#
# 策略（三个脚本各自把它翻译成自己的行为）：
#
#   pinned  钉在 ref 指定的 tag 上，并建同名本地分支。
#           maps/ 里的行号按这个 tag 写，**自动升版会让全部行号失效**，
#           所以：check 只报 NOTICE、update 只 fetch 不切换、bootstrap 发现版本不符只提示。
#           升版是人工任务：改这里的 ref + 校对地图行号。
#
#   track   追踪 ref 指定的分支。check 比对该分支远端 HEAD，update 用 merge --ff-only。
#
#   latest  追版本号最高的 tag（Apple drop 的代码在 tag 上，main 常落后）。
#           check 比对最高 tag，update 自动 checkout 过去。
#
# clone 附加参数：blob:none 部分克隆用于历史体量大、只读研究的仓库
#（两份 Swift Foundation，以及有三十年 CVS 历史的 gnustep-base）。
# 部分克隆只把**历史**里的 blob 留在远端，checkout 出来的工作区文件是齐的，
# 离线读源码不受影响。
#
# tag 过滤 glob：留空表示「所有 tag 都算版本号」。
#   仓库里混着非版本号的历史 tag 时必须填，否则 `sort -V` 会把它们排到最高，
#   于是每次 check-updates.sh 都报一条永远消不掉的假「有新版本」。
#   gnustep-base 就是这种情况：它有 1998 年的 `start-cvs` 和一堆 `snapshot-9808xx`，
#   真正的发布 tag 只有 `base-*`。glob 直接交给 git（`tag --list` / `ls-remote --tags`）。
#
# 源码目录一律不进本仓库版本管理，由 .gitignore 忽略；bootstrap.sh 会逐个核对这一点。

SOURCES=(
  "objc4|new objc4|objc4|https://github.com/apple-oss-distributions/objc4.git|pinned|objc4-951.7|"
  "libdispatch|libdispatch|libdispatch|https://github.com/apple/swift-corelibs-libdispatch.git|track|main|--filter=blob:none"
  "libdispatch-apple|libdispatch-apple|libdispatch-apple|https://github.com/apple-oss-distributions/libdispatch.git|latest||"
  "foundation|swift-corelibs-foundation|corelibs-foundation|https://github.com/apple/swift-corelibs-foundation.git|track|main|--filter=blob:none"
  "swift-foundation|swift-foundation|swift-foundation|https://github.com/apple/swift-foundation.git|track|main|--filter=blob:none"
  "cf|CF-1153.18-apple|CoreFoundation|https://github.com/apple-oss-distributions/CF.git|track|main|"
  "gnustep|gnustep-base|gnustep-base|https://github.com/gnustep/libs-base.git|pinned|base-1_31_1|--filter=blob:none|base-*"
  "afnetworking|third-party/AFNetworking|AFNetworking|https://github.com/AFNetworking/AFNetworking.git|pinned|4.0.1|"
  "jsonmodel|third-party/JSONModel|JSONModel|https://github.com/jsonmodel/jsonmodel.git|pinned|1.8.0|"
  "yymodel|third-party/YYModel|YYModel|https://github.com/ibireme/YYModel.git|pinned|1.0.4|"
  "sdwebimage|third-party/SDWebImage|SDWebImage|https://github.com/SDWebImage/SDWebImage.git|pinned|5.21.7|"
)

# ── 查询 ────────────────────────────────────────────────────────────────
# source_lookup <目标名>
# 命中则把字段写进 SRC_KEY / SRC_DIR / SRC_NAME / SRC_URL / SRC_POLICY / SRC_REF /
# SRC_FILTER / SRC_TAGGLOB 并返回 0（清单里省略末尾字段的行，对应变量为空串）
source_lookup() {
  local spec
  for spec in "${SOURCES[@]}"; do
    IFS='|' read -r SRC_KEY SRC_DIR SRC_NAME SRC_URL SRC_POLICY SRC_REF SRC_FILTER SRC_TAGGLOB <<< "$spec"
    [ "$SRC_KEY" = "$1" ] && return 0
  done
  return 1
}

# source_all_keys —— 按清单顺序输出全部目标名
source_all_keys() {
  local spec key
  for spec in "${SOURCES[@]}"; do
    IFS='|' read -r key _ <<< "$spec"
    printf '%s\n' "$key"
  done
}

# source_policy_desc <策略> —— 给人看的一句话说明
source_policy_desc() {
  case "$1" in
    pinned) printf '钉在 tag，只报告不自动切' ;;
    track)  printf '追踪分支，ff-only 更新' ;;
    latest) printf '追最新 tag，自动切换' ;;
    *)      printf '%s' "$1" ;;
  esac
}

# source_norm_url <url> —— 比对 remote 用，归一到「主机/路径」
# SSH（git@github.com:owner/repo.git）与 HTTPS（https://github.com/owner/repo）
# 指的是同一个仓库，本地用哪种协议 clone 都算数，不能因此报「来源不符」。
source_norm_url() {
  local u="$1"
  u="${u%/}"
  u="${u%.git}"
  u="${u#git+ssh://}"; u="${u#ssh://}"; u="${u#https://}"; u="${u#http://}"; u="${u#git://}"
  u="${u#*@}"          # 去掉 user@ / git@
  local slash='/'      # 直接写 ${u/:/\/} 在 bash 3.2 会留下反斜杠，故用变量
  u="${u/:/$slash}"    # scp 式 host:path → host/path
  printf '%s' "$u" | tr '[:upper:]' '[:lower:]'
}

# source_local_state <目录名> —— 本地是否已有下载好的源码
#   0 已是 git 仓库   1 目录不存在   2 目录被占用（存在但不是 git 仓库）
source_local_state() {
  local path="$SOURCES_ROOT/$1"
  [ -e "$path" ] || return 1
  [ -d "$path/.git" ] || return 2
  return 0
}

# 供上面几个函数定位工作区；三个脚本 source 本文件前已设好各自的 ROOT
SOURCES_ROOT="${SOURCES_ROOT:-${ROOT:-.}}"
