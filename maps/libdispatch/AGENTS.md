# libdispatch（GCD）Swift 开源版 —— 用途与差异

`apple/swift-corelibs-libdispatch`，分支 `main`，blobless clone。
**本文行号按 commit `c48e92d9` 写；这份追 main，升版后行号会漂，引用务必带 commit。**

## 先看这条

**研究 iOS/macOS 的 GCD 行为不要用本目录，用 [`../libdispatch-apple/`](../libdispatch-apple/AGENTS.md)。**
本目录的价值只有两个：跨平台实现（Linux/Windows/BSD），以及查 Swift 侧 API 封装。

目录结构与 `../libdispatch-apple/` 基本一致，文件地图直接看那份 `AGENTS.md`，**但行号一律不通用**。

## 与 Apple drop 的实质差异

| | 本目录 | `../libdispatch-apple/` |
|---|---|---|
| `src/queue.c` | 7622 行 | 9085 行 |
| `src/workgroup.c` | **无** | 2030 行 |
| `src/eventlink.c` | **无** | 561 行 |
| `exclavekit/`、`client_callout.mm` | **无** | 有 |
| `event/event_epoll.c`、`event_windows.c` | 有（跨平台后端） | 有，但 Darwin 走 `event_kevent.c` |

`dispatch_workgroup`（实时线程调度）整个模块在本目录不存在。

## 本目录独有、值得看的部分

| 路径 | 内容 |
|---|---|
| `src/swift/` | `Dispatch.swift`、`Queue.swift`、`Block.swift`、`Data.swift`、`IO.swift` + `Dispatch.apinotes` —— GCD 的 Swift API 封装层 |
| `src/event/event_epoll.c` | Linux 事件后端（对照 Darwin 的 kqueue 看后端抽象） |
| `src/event/event_windows.c` | Windows 后端 |
| `src/shims/` | 比 Apple 版多 `android_stubs.h`、`generic_win_stubs.c` 等 |

## 常用符号（仅本目录有效）

| 符号 | 位置 |
|---|---|
| `dispatch_async` | `src/queue.c:921` |
| `dispatch_sync` | `src/queue.c:1948` |
| `_dispatch_main_queue_callback_4CF` | `src/queue.c:7082` |
| `dispatch_once_f` | `src/once.c:52` |
| `dispatch_group_*` | `src/semaphore.c`（同 Apple 版，行号一致） |
