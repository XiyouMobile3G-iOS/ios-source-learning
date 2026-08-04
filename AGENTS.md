# AGENTS.md —— Apple 底层源码学习工作区

本目录是 objc runtime / CoreFoundation（RunLoop）/ libdispatch（GCD）/ Foundation 的源码研究区。
**本文件只给规范、索引和跨仓库关系。具体文件地图在各子目录的 `AGENTS.md` 里，按需读取。**

---

## 规范一：先更新源码，再回答

只要问题涉及 objc runtime / RunLoop / CoreFoundation / GCD / Foundation，无论看起来多简单：

1. 先运行 `./check-updates.sh`，**按退出码决定下一步**；
2. 再 grep / 读实际源码得结论；
3. 引用带 `文件:行号`，并注明版本（commit / drop 号）。

**不要直接跑 `update-sources.sh`**，它会拉一大段 fetch 日志进上下文。

| 退出码 | 输出开头 | 该做什么 |
|---|---|---|
| 0 | `UPTODATE` | 直接读源码，**不要**跑 update-sources.sh |
| 10 | `UPDATE` | 跑 `./update-sources.sh` 再读 |
| 2 | `ERROR` | 视为「未能更新」，声明基于本地版本后作答 |

两个脚本都接受目标名收窄范围：`objc4` / `libdispatch` / `libdispatch-apple` / `foundation` / `cf`，
如 `./check-updates.sh libdispatch-apple`。其余参数见脚本 `-h`。

**禁止凭记忆回答。** CF 停更在 10.13、两份 CF 有差异、libdispatch 有两套、objc4 每 drop 都在变——凭印象几乎必错。

例外：用户明说「不用更新」「就用本地这份」；或同一轮对话中刚检查过。
更新失败时**必须声明**「基于本地 X 版本、未能更新」再作答。

## 规范二：对话式讲解，控制回复长度

**讲解源码时用对话推进，不要一次倾倒一大段。**

- 单次回复控制在 **30 行以内**（不含代码块；代码块单次不超过 25 行）。
- 一次只讲**一个**问题点，讲完停下，给出「下一步可以看 X / Y」让用户选方向。
- 需要展开的长内容，拆成多轮，由用户决定深浅和节奏。
- 用户明确要「完整梳理」「一次讲完」「写成文档」时才放开长度。
- 长表格、全量文件清单不要写进回复——写进对应的 `AGENTS.md`，回复里只给结论和指路。

代码引用同样克制：贴关键的 5–15 行，不要整个函数体倒出来。

## 规范三：渐进式披露，防止上下文溢出

**不要一次性读入整个源码树，也不要通读大文件。**

1. 先看下面的「按任务定位」表，确定目标仓库；
2. 读那个仓库的 `AGENTS.md`（每份 200 行内），拿到文件名和行号；
3. 用 `Read` 的 `offset`/`limit` 只读需要的那几十行，或用 `grep -n` 精确定位。

`CFRunLoop.c` 3955 行、`queue.c` 9085 行、`CFString.c` 6570 行——整读任何一个都会挤爆上下文。

---

## 按任务定位

| 问题涉及 | 去读 | 说明 |
|---|---|---|
| RunLoop 循环 / 保活 / mode / source / timer / observer | [`CF-1153.18-apple/AGENTS.md`](./CF-1153.18-apple/AGENTS.md) | RunLoop 权威实现，符号行号表 |
| CF 对象模型 / 集合 / 字符串 / plist / Bundle | 同上 | 按主题分组的文件表 |
| GCD 队列 / async / sync / group / semaphore / once / source | [`libdispatch-apple/AGENTS.md`](./libdispatch-apple/AGENTS.md) | macOS 真实实现，**优先用这份** |
| `dispatch_workgroup` / `eventlink` / 实时线程调度 | 同上 | 仅 Apple drop 有 |
| GCD 的 Linux/Windows 实现、跨平台差异 | [`libdispatch/AGENTS.md`](./libdispatch/AGENTS.md) | Swift 开源版 |
| Foundation（Swift 层）/ 10.13 后 CF 的新增 | [`swift-corelibs-foundation/AGENTS.md`](./swift-corelibs-foundation/AGENTS.md) | 查新与对照 |
| 类实现化 / category / ivar / isa / 引用计数 / msgSend | [`new objc4/CLAUDE.md`](./new%20objc4/CLAUDE.md) | 已有六份子模块记忆 |
| 自动释放池、RunLoop 与 GCD 主队列的咬合 | 本文「跨仓库交叉点」一节 | 跨仓库，留在这里 |

---

## 目录总览

| 目录 | 内容 | 版本 |
|---|---|---|
| `new objc4/` | ObjC runtime | 分支 `objc4-951.7` |
| `CF-1153.18-apple/` | CoreFoundation，**RunLoop 权威版** | CF-1153.18（macOS 10.13.6） |
| `libdispatch-apple/` | GCD，**macOS drop** | tag `libdispatch-1542.100.32`（detached HEAD） |
| `libdispatch/` | GCD，Swift 开源版 | main |
| `swift-corelibs-foundation/` | Swift CF + Foundation | main |

## 选型铁律

研究 **iOS/macOS 真实行为**时：

- CoreFoundation → **`CF-1153.18-apple/`**（不是 swift-corelibs）
- GCD → **`libdispatch-apple/`**（不是 `libdispatch/`）

Swift 开源版含大量 Linux/Windows 适配，行号和实现都对不上真实二进制；差异明细见各自 `AGENTS.md`。
反过来，查「10.13 之后 CF 怎么演进的」只能看 swift-corelibs——Apple 已停止开源 CF。

---

## 跨仓库交叉点

三处咬合，只在这里记，子文件不重复。

### 1. CF ←→ GCD：主队列被主 RunLoop 抽干

也是「主 RunLoop 不需要保活」的根因：

- `CF-1153.18-apple/CFRunLoop.c:58-69` —— CF 声明 GCD 后门符号 `_dispatch_get_main_queue_port_4CF` / `_dispatch_main_queue_callback_4CF`
- `CFRunLoop.c:838` —— `__CFRunLoopModeIsEmpty` 中主 RunLoop + common mode 直接 `return false`，注释 `// represents the libdispatch main queue`
- `CFRunLoop.c:2344` —— **同一个条件**决定是否监听 dispatch 端口
- `CFRunLoop.c:1590` —— 收到消息后回调进 GCD
- `libdispatch-apple/src/queue.c:8367` —— GCD 侧落点（Swift 版在 `libdispatch/src/queue.c:7071`）

一句话：`dispatch_async(main_queue)` 不是 GCD 自己跑的，是主 RunLoop 收到 mach 消息后回调 GCD 执行的。

### 2. CF ←→ objc4：自动释放池

- `new objc4/runtime/NSObject.mm:2270` `_objc_autoreleasePoolPush` / `:2276` `_objc_autoreleasePoolPop`
- 主 RunLoop 注册的 observer：`Entry` → push；`BeforeWaiting` → pop 后 push；`Exit` → pop
- 回调路径 `CF-1153.18-apple/CFRunLoop.c:1668` `__CFRunLoopDoObservers`
- 注意：注册这些 observer 的代码在 **UIKit/Foundation**，不在本工作区，只能靠符号断点观察

### 3. GCD ←→ objc4

`libdispatch-apple/src/object.m`、`os/object.h` 的 `OS_OBJECT_USE_OBJC` 决定 dispatch 对象是否是真 ObjC 对象（能否 ARC 管理）。对照 objc4 的 `isa` 布局看。

---

## 更新工具 `update-sources.sh`

```bash
./update-sources.sh                        # 全部
./update-sources.sh -n                     # 演练
./update-sources.sh -f                     # 允许 stash 后更新脏工作区
./update-sources.sh libdispatch-apple cf   # 指定目标
./update-sources.sh -h                     # 帮助
```

目标：`objc4` / `libdispatch` / `libdispatch-apple` / `foundation` / `cf`。四种策略：

| 目标 | 策略 | 原因 |
|---|---|---|
| `objc4` | 只 fetch，报告有无新 drop，**永不动工作区** | 在自建分支上且有本地笔记未提交 |
| `libdispatch`、`foundation` | `merge --ff-only` | 干净的 tracking 分支 |
| `libdispatch-apple` | 自动 checkout 到版本号最高的 tag | drop 代码在 tag 上，`main` 常落后 |
| `cf` | 比对 tarball 索引版本，有新版解压成**新目录** | 非 git，且上游已停更 |

安全约束：工作区脏默认跳过（`-f` 才 stash）；本地领先上游判为分叉只报告；只用 `--ff-only`；CF 新版不覆盖旧目录。fetch 失败自动重试 3 次。

---

## 工作约定

- 四份源码都是**只读研究**，不追求可构建（objc4 需 internal SDK，CF 是精简包缺文件）。
- 各仓库里的 `AGENTS.md` / `CLAUDE.md` 笔记已写入各自 `.git/info/exclude`，不会污染 `git status`，也就不会让更新脚本跳过合并。
- 引用代码带 `文件:行号` + 版本号；两个 Swift 仓库会随更新变动，最好同时记 commit。
- 缩进跟随各仓库原有风格（objc4 是 4 空格，与用户全局 OC 的 2 空格规范不同）。
