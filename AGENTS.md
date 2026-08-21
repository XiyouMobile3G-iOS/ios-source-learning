# AGENTS.md —— iOS 源码学习工作区

本目录是两类源码的研究区：

- **Apple 底层**：objc runtime / CoreFoundation（RunLoop）/ libdispatch（GCD）/ Foundation
- **常用第三方库**（全在 `third-party/` 一个文件夹里）：AFNetworking / JSONModel / SDWebImage

**本文件只给规范、索引和跨仓库关系。具体文件地图在各子目录的 `AGENTS.md` 里，按需读取。**

---

## 规范零：先确认工作区已搭好

本仓库**不包含任何源码本体**，五份 Apple 源码 + 三份第三方库都由 `bootstrap.sh` 从各自上游克隆。
新克隆的仓库里，下表所有子目录都还不存在，本文件后面的链接也就全是死链。

动手前先跑一次体检（它会逐个核对本地有没有、版本对不对，且不改动任何东西）：

```bash
./bootstrap.sh --check    # 只体检：本地有什么、缺什么、版本是否对得上笔记
```

缺源码时才运行下载；**目标名可以收窄，别动辄全量拉**：

```bash
./bootstrap.sh                                     # 下载缺失的全部 + 挂载笔记，可重复运行
./bootstrap.sh afnetworking jsonmodel sdwebimage    # 只补三份第三方库（约 70 MB）
```

首次全量约 2–3 GB、耗时较长，**必须先告知用户再执行**，不要在回答问题的中途默默拉一遍。
`bootstrap.sh` 下载前会核对本地：已有的不会重复下载；版本与笔记基准不一致时**只提示不自动切**，
这种情况要把它的提示原样转达用户，不要自作主张执行 checkout——切版本会让笔记里的行号全部失效。

## 规范一：先更新源码，再回答

只要问题涉及 objc runtime / RunLoop / CoreFoundation / GCD / Foundation /
AFNetworking / JSONModel / SDWebImage，无论看起来多简单：

1. 先运行 `./check-updates.sh`，**按退出码决定下一步**；
2. 再 grep / 读实际源码得结论；
3. 引用带 `文件:行号`，并注明版本（commit / drop 号）。

**不要直接跑 `update-sources.sh`**，它会拉一大段 fetch 日志进上下文。

| 退出码 | 输出开头 | 该做什么 |
|---|---|---|
| 0 | `UPTODATE` | 直接读源码，**不要**跑 update-sources.sh |
| 10 | `UPDATE` | 跑 `./update-sources.sh` 再读 |
| 2 | `ERROR` | 先申请网络权限，用完全相同的参数重跑一次 `check-updates.sh`；重跑仍返回 2 才视为「未能更新」。明细是「配置要求分支…请先切回」时不是网络问题，转达用户切回分支 |

首次检查返回退出码 2 时，可能只是 agent 沙箱无法访问网络或本机代理。agent **必须申请沙箱外网络权限后重跑一次同一条 `check-updates.sh` 命令**，不得改用手动 `git fetch`、`git pull` 或 `git ls-remote` 绕过脚本。只有获得网络权限后的重跑仍返回 2，才声明基于本地版本作答。

例外：ERROR 明细是「配置要求分支 X，当前在 Y，请先切回 X」（track 目标本地所在分支与 `sources.sh` 的 ref 不符）时，与网络无关——把提示原样转达用户、请其切回配置分支，**不要**重试，也**不要**自行 checkout（与「规范零」一致）。`update-sources.sh` 对同一目标也会跳过并提示分支不符。

两个脚本都接受目标名收窄范围：`objc4` / `libdispatch` / `libdispatch-apple` / `foundation` / `cf` /
`afnetworking` / `jsonmodel` / `sdwebimage`，如 `./check-updates.sh sdwebimage`。其余参数见脚本 `-h`。

三份第三方库钉在具体 release tag 上（笔记行号按该 tag 写），策略同 objc4：**有新版本只出 `NOTICE`、不改工作区**，
不要因为看到 NOTICE 就去跑 `update-sources.sh`，也不要自行 `git checkout` 升版——升版会让笔记里全部行号失效。

**禁止凭记忆回答。** CF 停更在 10.13、两份 CF 有差异、libdispatch 有两套、objc4 每 drop 都在变——凭印象几乎必错。
第三方库同理：AFNetworking 4.x 与 2.x 是两套实现（**4.x 没有常驻 RunLoop 线程**）、SDWebImage 5.x 全面协议化，
按博客记忆回答几乎必错。

例外：用户明说「不用更新」「就用本地这份」；或同一轮对话中刚检查过。
更新失败时**必须声明**「基于本地 X 版本、未能更新」再作答。

## 规范二：教学提示词渐进式路由

当用户请求「讲解」「学习」「原理」「为什么」或源码分析时：

1. 必须先读取并遵循 [`prompts/teaching/INDEX.md`](./prompts/teaching/INDEX.md)。
2. 用户未指定其他已注册方法或风格时，使用索引声明的默认教学方法。
3. 只读取索引为本次讲解选中的提示词文件，不要扫描或一次性读入整个提示词目录。

## 规范三：渐进式披露，防止上下文溢出

**不要一次性读入整个源码树，也不要通读大文件。**

1. 先看下面的「按任务定位」表，确定目标仓库；
2. 读那个仓库的 `AGENTS.md`（每份 200 行内），拿到文件名和行号；
3. 用 `Read` 的 `offset`/`limit` 只读需要的那几十行，或用 `grep -n` 精确定位。

`CFRunLoop.c` 3955 行、`queue.c` 9085 行、`CFString.c` 6570 行——整读任何一个都会挤爆上下文。
第三方库体量小得多（`third-party/` 合计约 4.5 万行），但同样按笔记给的行号跳读，别整目录展开。

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
| AFNetworking：session 封装 / 序列化 / SSL Pinning / task swizzle / 图片下载 | [`third-party/AFNetworking/AGENTS.md`](./third-party/AFNetworking/AGENTS.md) | 4.0.1，**只有 NSURLSession 一条路径**。索引，含 4 个模块 |
| JSONModel：属性内省 / JSON↔Model 映射 / 类型转换 | [`third-party/JSONModel/AGENTS.md`](./third-party/JSONModel/AGENTS.md) | 1.8.0，objc runtime 的应用样本。索引，含 4 个模块 |
| SDWebImage：图片缓存 / 下载调度 / 解码 / 动图 | [`third-party/SDWebImage/AGENTS.md`](./third-party/SDWebImage/AGENTS.md) | 5.21.7，5.x 协议化架构。索引，含 5 个模块 |

三个第三方库都是**两级结构**：库根的 `AGENTS.md` 只做路由与跨模块串联，符号表在各模块目录自己的 `AGENTS.md` 里。
**先读库根索引，再按它的表选中一个模块**，不要一次读多份模块文档。

---

## 目录总览

| 目录 | 内容 | 版本 |
|---|---|---|
| `new objc4/` | ObjC runtime | 分支 `objc4-951.7` |
| `CF-1153.18-apple/` | CoreFoundation，**RunLoop 权威版** | 分支 `main` @ `CF-1153.18`（macOS 10.13.6，上游已停更） |
| `libdispatch-apple/` | GCD，**macOS drop** | tag `libdispatch-1542.100.32`（detached HEAD） |
| `libdispatch/` | GCD，Swift 开源版 | main |
| `swift-corelibs-foundation/` | Swift CF + Foundation | main |
| `third-party/AFNetworking/` | 网络库，按 核心 / UIKit / 测试 分模块 | tag `4.0.1`（同名本地分支） |
| `third-party/JSONModel/` | JSON 模型映射，按 核心 / 转换 / 网络（废弃）分模块 | tag `1.8.0`（同名本地分支） |
| `third-party/SDWebImage/` | 图片加载与缓存，按 Core / Private / MapKit / 测试 分模块 | tag `5.21.7`（同名本地分支） |
| `notes/` | 上面所有目录里全部笔记的**真身**，本仓库唯一版本管理的正文 | 跟随本仓库 |

第三方库集中放在 `third-party/` 一个文件夹里，与 Apple 源码的顶层目录区分开；
每份都是独立 git 仓库，同样 `.gitignore`、同样由 `bootstrap.sh` 克隆。

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

### 4. 第三方库 ←→ 底层

第三方库的价值在于「底层机制的真实用法」，讲解时优先打通这几条线，不要就库论库：

- **JSONModel ←→ objc4**：`JSONModel.m:530` `__inspectProperties` 用 `class_copyPropertyList` /
  `property_getAttributes` 解析类型编码，结果用 `objc_setAssociatedObject` 挂在类对象上。
  类型编码的定义在 `new objc4/runtime/`，关联对象实现见 `new objc4/runtime/objc-references.mm`。
- **AFNetworking ←→ objc4**：`AFURLSessionManager.m:330` `af_swizzleSelector` /
  `:407` 逐层查找真正实现 `resume` 的类，是 `method_exchangeImplementations` 与类簇继承链的实战案例。
- **AFNetworking / SDWebImage ←→ GCD**：回调线程模型都落在 `dispatch_get_main_queue()` 上
  （`AFURLSessionManager.m:210`、SDWebImage 的 `SDCallbackQueue`），
  为什么「回调一定回主线程」要接到 `libdispatch-apple` 与主 RunLoop 的咬合（本节第 1 条）。
- **SDWebImage ←→ RunLoop**：动图播放用 `SDDisplayLink`（`third-party/SDWebImage/SDWebImage/Private/SDDisplayLink.m`），
  CADisplayLink 挂 RunLoop mode 的行为在 `CF-1153.18-apple/CFRunLoop.c` 一侧。

---

## 更新工具 `update-sources.sh`

```bash
./update-sources.sh                        # 全部
./update-sources.sh -n                     # 演练
./update-sources.sh -f                     # 允许 stash 后更新脏工作区
./update-sources.sh libdispatch-apple cf   # 指定目标
./update-sources.sh -h                     # 帮助
```

目标：`objc4` / `libdispatch` / `libdispatch-apple` / `foundation` / `cf` /
`afnetworking` / `jsonmodel` / `sdwebimage`。三种策略：

| 目标 | 策略 | 原因 |
|---|---|---|
| `objc4`、`afnetworking`、`jsonmodel`、`sdwebimage` | 只 fetch，报告有无新版本，**永不动工作区** | 钉在指定 tag，笔记行号按该 tag 写 |
| `libdispatch`、`foundation`、`cf` | `merge --ff-only` | 干净的 tracking 分支 |
| `libdispatch-apple` | 自动 checkout 到版本号最高的 tag | drop 代码在 tag 上，`main` 常落后 |

要给第三方库升版，得**同时**改 `sources.sh` 里的 ref 和对应笔记里的全部行号，属于人工任务，agent 不要自作主张。

## 三个脚本与一份清单

| 文件 | 作用 |
|---|---|
| `sources.sh` | 源码清单（目标名 / 目录 / 上游 / 策略 / ref），**三个脚本共用的唯一事实来源** |
| `bootstrap.sh` | 下载源码（下载前核对本地）+ 挂载笔记 |
| `check-updates.sh` | 只读探测，秒级、带缓存 |
| `update-sources.sh` | 执行更新，只动已下载的源码 |

对 agent 有意义的三条：

- 三个脚本的目标名完全一致，都来自清单；打错目标名会立刻报错并列出可用值。
- 源码目录一律不进本仓库，`bootstrap.sh` 每轮用 `git check-ignore` 复核；**任何时候都不要把源码 `git add` 进来**。
- 新增源码只改 `sources.sh` 一行，不要再去三个脚本里各抄一份。完整用法见 [`README.md`](./README.md) 的「脚本使用说明」。

安全约束：工作区脏默认跳过（`-f` 才 stash）；本地领先上游判为分叉只报告；只用 `--ff-only`。fetch 失败自动重试 3 次。

CF 的仓库是 `apple-oss-distributions/CF`，`main` 停在 `CF-1153.18`（2021 年最后一次 push），实际不会再有更新；留着 git 主要是为了能 `git diff CF-1151.16 CF-1153.18` 对照历史版本。

---

## 工作约定

- 八份源码都是**只读研究**，不追求可构建（objc4 需 internal SDK，CF 是精简包缺文件；三份第三方库理论上可构建，但本工作区不做这件事）。
- 八个源码目录都是独立 git 仓库，不做 submodule，一律 `.gitignore`（第三方库整个 `/third-party/` 被忽略），互不干扰。
- **笔记的真身在 `notes/`**，源码树里那些 `AGENTS.md` / `CLAUDE.md` 都是指向它的符号链接（`bootstrap.sh` 挂的）。
  就地编辑 `new objc4/runtime/CLAUDE.md` 等于编辑 `notes/new objc4/runtime/CLAUDE.md`，改动自动进入本仓库的 `git status`——**记得提交**。
- 这些链接同时写进了各子仓库的 `.git/info/exclude`，不污染子仓库 `git status`，也就不会让更新脚本因「工作区脏」跳过合并。
- 新增笔记时**必须写进 `notes/` 再跑 `./bootstrap.sh --notes-only` 挂载**；直接在源码树里新建文件会成为游离的未跟踪文件，别人 clone 不到。
- 引用代码带 `文件:行号` + 版本号；两个 Swift 仓库会随更新变动，最好同时记 commit。
  第三方库钉在 tag，引用写成 `AFURLSessionManager.m:210`（AFNetworking 4.0.1）这样即可。
- SDWebImage 的 `Core/` 与 `include/SDWebImage/` 是同一份头文件的两个副本，grep 结果会翻倍，**行号一律引 `Core/`**。
- 缩进跟随各仓库原有风格（objc4 是 4 空格，与用户全局 OC 的 2 空格规范不同）。
