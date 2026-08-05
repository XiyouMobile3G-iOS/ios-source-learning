# libdispatch（GCD）macOS drop —— 文件地图

`apple-oss-distributions/libdispatch`，当前 **detached HEAD @ tag `libdispatch-1542.100.32`**。
与 objc4 同属 drop 型仓库：**代码在 tag 上，`main` 分支通常落后**，切版本用 `git checkout libdispatch-<版本>`（已是完整 clone，离线可切）。

**研究 iOS/macOS GCD 行为用本目录**，不要用 `../libdispatch/`（Swift 版，缺模块且行号不同）。

规模：`src/` 50777 行。`queue.c` 9085 行，**禁止整读**。

---

## 顶层目录

| 目录 | 内容 |
|---|---|
| `src/` | 实现主体 |
| `dispatch/` | 公开头文件：`queue.h` `source.h` `group.h` `semaphore.h` `once.h` `io.h` `data.h` `block.h` `time.h` `object.h` |
| `private/` | SPI：`queue_private.h` `workloop_private.h` `mach_private.h` `source_private.h` `layout_private.h` |
| `os/` | `object.h`/`object_private.h`（`OS_OBJECT_USE_OBJC`）、voucher、firehose |
| `man/` | **语义描述比头文件注释完整，查 API 行为优先看这里** |
| `tests/` | 查边界行为的实测依据 |
| `tools/` | `dispatch_trace.d` 等 dtrace 脚本 |

---

## `src/` 关键文件

| 文件 | 行数 | 内容 |
|---|---|---|
| `queue.c` | 9085 | 队列核心：串行/并发、根队列、主队列、线程池 |
| `mach.c` | 3620 | mach port 事件源 |
| `event/event_kevent.c` | 3566 | kqueue 后端（Darwin 实际用的） |
| `inline_internal.h` | 2944 | **热路径 inline 函数**，读 `queue.c` 卡住多半在这 |
| `io.c` | 2785 | `dispatch_io` 异步 IO |
| `voucher.c` | 2191 | voucher（活动追踪 / QoS 传递） |
| `workgroup.c` | 2030 | **`dispatch_workgroup`，实时线程调度（音视频/游戏）。Swift 版没有** |
| `init.c` | 1959 | 全局初始化、**根队列表静态定义**（查优先级映射看这） |
| `source.c` | 1528 | `dispatch_source` 通用层 |
| `firehose/` | 2944 | 日志传输 |
| `queue_internal.h` | 1390 | **队列结构体定义**，读 `queue.c` 前必读 |
| `internal.h` | 1223 | 总内部头 |
| `introspection.c` | 1210 | 调试内省接口 |
| `event/event.c` | 1242 | 事件后端抽象层 |
| `allocator.c` | 809 | continuation 分配器 |
| `apply.c` | 800 | `dispatch_apply` 并行循环 |
| `shims/lock.c` | 766 | 锁原语（`shims/` 是平台抽象：原子、TSD、lock） |
| `object_internal.h` | 694 | dispatch 对象模型（引用计数、vtable） |
| `eventlink.c` | 561 | **`dispatch_eventlink`，轻量线程间唤醒。Swift 版没有** |
| `semaphore.c` | 407 | 信号量 **+ dispatch_group** |
| `once.c` | 71 | `dispatch_once` |

---

## 常用符号行号

| 符号 | 位置 |
|---|---|
| `dispatch_async` | `queue.c:958` |
| `dispatch_sync` | `queue.c:2051` |
| **`_dispatch_main_queue_callback_4CF`** | `queue.c:8367` |
| `dispatch_once_f` | `once.c:52` |
| `dispatch_apply` | `apply.c:363` |
| `dispatch_group_create` | `semaphore.c:168` |
| `dispatch_group_enter` | `semaphore.c:309` |
| `dispatch_group_leave` | `semaphore.c:275` |
| `dispatch_group_wait` | `semaphore.c:225` |
| `dispatch_group_notify` | `semaphore.c:363` |

**`dispatch_group` 全在 `semaphore.c` 里，没有 `group.c`**——这是找 GCD 源码最容易扑空的一处。

---

## 易错点

- 想找某函数却 grep 不到函数体：多半是宏生成的，或实体在 `inline_internal.h`。
- `queue.c` 里大量 `_dispatch_*` 前缀的内部函数分散在 `*_internal.h`，先 `grep -rn "符号名" src/` 再定位。
- 与 CF 的咬合点（`_dispatch_main_queue_callback_4CF`）见父目录 `../AGENTS.md` 的「跨仓库交叉点」。

## 与 Swift 版的差异

`../libdispatch/` 独缺：`workgroup.c`、`eventlink.c`、`exclavekit/`、`client_callout.mm`。
`queue.c` 7609 行 vs 本目录 9085 行，**同名函数行号全不一样**。跨平台实现（epoll / Windows）只有 Swift 版有。
