#!/bin/bash
#
# progress.sh —— 给 bootstrap.sh / update-sources.sh 用的 git 传输进度条
#
# 被 source 进去，本身不做事。终端下把 git --progress 的 \r 刷新画成一条
# `[████░░░░]  42%  objc4  2/10  下载  120.4 MiB | 3.1 MiB/s`；
# 非终端不画条，让 git 自己的 `Receiving objects: xx%` 进日志。
#
# 环境变量（测试用）：
#   PROGRESS_FILL / PROGRESS_EMPTY  条的实心/空心字符
#   PROGRESS_WIDTH                  条宽，默认 24
#   PROGRESS_FORCE                  非 TTY 也画条
#   PROGRESS_NEWLINE                每次刷新换行（便于测），默认用 \r 原地更新
#

# progress_bar_string <宽度> <0-100>
progress_bar_string() {
  local width="$1" pct="$2"
  local fill="${PROGRESS_FILL:-█}"
  local empty="${PROGRESS_EMPTY:-░}"
  local filled rest fill_s empty_s

  case "$width" in
    ''|*[!0-9]*) width=24 ;;
  esac
  case "$pct" in
    ''|*[!0-9]*) pct=0 ;;
  esac
  [ "$width" -gt 0 ] || width=1
  [ "$pct" -gt 100 ] && pct=100

  # printf 填空格再换字符；不用 tr，macOS tr 会把多字节的 █ 拆开
  filled=$((pct * width / 100))
  rest=$((width - filled))
  fill_s=$(printf '%*s' "$filled" '')
  empty_s=$(printf '%*s' "$rest" '')
  printf '%s%s' "${fill_s// /$fill}" "${empty_s// /$empty}"
}

# progress_phase_pct <阶段> <该阶段 0-100>
# 同一仓库内条只往前走：枚举 0–5，压缩 5–10，下载 10–90，解包 90–100。
progress_phase_pct() {
  local phase="$1" pct="$2"
  case "$pct" in
    ''|*[!0-9]*) pct=0 ;;
  esac
  [ "$pct" -gt 100 ] && pct=100
  case "$phase" in
    枚举) printf '%s' $(( pct * 5 / 100 )) ;;
    压缩) printf '%s' $(( 5 + pct * 5 / 100 )) ;;
    下载) printf '%s' $(( 10 + pct * 80 / 100 )) ;;
    解包) printf '%s' $(( 90 + pct * 10 / 100 )) ;;
    *)    printf '%s' "$pct" ;;
  esac
}

# progress_overall_pct <已完成仓库数> <当前仓库 0-100> <总仓库数>
# 把「第几个仓库」和当前仓库内部百分比叠成一条 0–100 的总进度。
progress_overall_pct() {
  local done="$1" current="$2" total="$3"
  case "$done" in ''|*[!0-9]*) done=0 ;; esac
  case "$current" in ''|*[!0-9]*) current=0 ;; esac
  case "$total" in ''|*[!0-9]*) total=0 ;; esac
  [ "$current" -gt 100 ] && current=100
  if [ "$total" -le 0 ]; then
    printf '0'
    return 0
  fi
  printf '%s' $(( (done * 100 + current) / total ))
}

# progress_parse_git_line <一行>
# 命中则写 PROGRESS_PCT / PROGRESS_PHASE / PROGRESS_DETAIL 并返回 0。
progress_parse_git_line() {
  local line="$1"
  PROGRESS_PCT=0
  PROGRESS_PHASE=""
  PROGRESS_DETAIL=""
  [ -n "$line" ] || return 1

  local phase=""
  case "$line" in
    *'Receiving objects:'*)     phase='下载' ;;
    *'Resolving deltas:'*)      phase='解包' ;;
    *'Counting objects:'*)      phase='枚举' ;;
    *'Compressing objects:'*)   phase='压缩' ;;
    *) return 1 ;;
  esac

  local pct=""
  if [[ "$line" =~ ([0-9]+)% ]]; then
    pct="${BASH_REMATCH[1]}"
  else
    return 1
  fi
  [ "$pct" -gt 100 ] && pct=100

  PROGRESS_PCT="$pct"
  PROGRESS_PHASE="$phase"

  if [[ "$line" =~ ([0-9][0-9.]*\ [KMG]iB)\ \|\ ([0-9][0-9.]*\ [KMG]iB/s) ]]; then
    PROGRESS_DETAIL="${BASH_REMATCH[1]} | ${BASH_REMATCH[2]}"
  fi
  return 0
}

progress_draw() {
  local pct="$1" text="$2"
  local width="${PROGRESS_WIDTH:-24}"
  local bar msg
  bar=$(progress_bar_string "$width" "$pct")
  msg=$(printf '  [%s] %3d%%  %s' "$bar" "$pct" "$text")

  if [ -n "${PROGRESS_NEWLINE:-}" ]; then
    printf '%s\n' "$msg" >&2
    return 0
  fi
  if [ -t 2 ] || [ -n "${PROGRESS_FORCE:-}" ]; then
    printf '\r%s\033[K' "$msg" >&2
  fi
}

progress_end() {
  [ -n "${PROGRESS_NEWLINE:-}" ] && return 0
  if [ -t 2 ] || [ -n "${PROGRESS_FORCE:-}" ]; then
    printf '\n' >&2
  fi
}

progress_handle_line() {
  local line="$1" label="$2" log="$3" done="$4" total="$5"
  line="${line%$'\n'}"
  line="${line%$'\r'}"
  [ -n "$line" ] || return 0

  if progress_parse_git_line "$line"; then
    local overall idx text repo_pct
    repo_pct=$(progress_phase_pct "$PROGRESS_PHASE" "$PROGRESS_PCT")
    overall=$(progress_overall_pct "$done" "$repo_pct" "$total")
    idx=$((done + 1))
    text="$label"
    [ "$total" -gt 0 ] && text="$label  ${idx}/${total}"
    [ -n "$PROGRESS_PHASE" ] && text="${text}  ${PROGRESS_PHASE}"
    [ -n "$PROGRESS_DETAIL" ] && text="${text}  ${PROGRESS_DETAIL}"
    progress_draw "$overall" "$text"
  else
    printf '%s\n' "$line" >> "$log"
  fi
}

# progress_consume <标签> <非进度行日志> <已完成数> <总数>
# 从 stdin 读 git --progress 的 \r 刷新流。
progress_consume() {
  local label="$1" log="$2" done="$3" total="$4"
  local buf rest line

  while IFS= read -r -d $'\r' buf || [ -n "$buf" ]; do
    rest="$buf"
    while [ -n "$rest" ]; do
      case "$rest" in
        *$'\n'*)
          line="${rest%%$'\n'*}"
          rest="${rest#*$'\n'}"
          ;;
        *)
          line="$rest"
          rest=""
          ;;
      esac
      progress_handle_line "$line" "$label" "$log" "$done" "$total"
    done
  done
  return 0
}

# git_run_progress <标签> <已完成数> <总数> <git 命令...>
# 终端：解析 --progress，画一条总进度。非终端：原样执行，git 自己往 stderr 打百分比。
git_run_progress() {
  local label="$1" done="$2" total="$3"
  shift 3
  local log git_rc=0

  if [ ! -t 2 ] && [ -z "${PROGRESS_FORCE:-}" ]; then
    "$@"
    return $?
  fi

  log=$(mktemp) || return 1
  # 只挂 RETURN：progress.sh 被 source，EXIT/INT trap 会盖掉调用方的。
  # 管道放进 if，避免调用方 set -eo pipefail 时在 rm 之前直接退出。
  trap 'rm -f -- "$log"' RETURN
  if "$@" 2>&1 | progress_consume "$label" "$log" "$done" "$total"; then
    git_rc=${PIPESTATUS[0]}
  else
    git_rc=${PIPESTATUS[0]}
  fi
  progress_end
  if [ "$git_rc" -ne 0 ] && [ -s "$log" ]; then
    cat "$log" >&2
  fi
  rm -f -- "$log"
  trap - RETURN
  return "$git_rc"
}
