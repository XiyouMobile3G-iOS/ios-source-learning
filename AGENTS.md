# AGENTS.md —— iOS 源码学习工作区

> **本文件有两个入口名，内容只有这一份。**
> `AGENTS.md` 是正文本体（Codex 等 agent 自动加载）；`CLAUDE.md` 是指向它的**符号链接**
> （Claude Code 自动加载）。两者在磁盘上是同一个文件，**读到任意一个就已经读全，不必再读另一个**。
>
> 之所以不用「一份正文 + 一份指针」——那是 `maps/` 下各目录的做法，在这里行不通：
> **指针只在「按需读取」时成立。根目录这两个文件是被自动注入上下文的，指针会被自动注入
> 这个机制本身架空**——agent 开局就拿到了一句「去读另一个文件」，然后直奔任务，再不回头。
> 这是实测结论，见规范二末尾。

本目录是三类源码的研究区：

- **Apple 底层**：objc runtime / CoreFoundation（RunLoop）/ libdispatch（GCD）/ Foundation（两份：外壳 + 实现体）
- **参照实现**：`gnustep-base/`——Apple 从未开源 Foundation 的 ObjC 实现，`NSNotificationCenter`、KVO 只能看它（**非 Apple 代码**，引用须注明）
- **常用第三方库**（全在 `third-party/` 一个文件夹里）：AFNetworking / JSONModel / YYModel / SDWebImage

**本文件只给规范、索引和跨仓库关系。具体文件地图在各子目录的 `AGENTS.md` 里，按需读取。**

---

## 规范零：先确认工作区已搭好

本仓库**不包含任何源码本体**，六份 Apple 源码 + 一份参照实现 + 四份第三方库都由 `bootstrap.sh` 从各自上游克隆。
新克隆的仓库里，下表所有子目录都还不存在，本文件后面的链接也就全是死链。

动手前先跑一次体检（它会逐个核对本地有没有、版本对不对，且不改动任何东西）：

```bash
./bootstrap.sh --check    # 只体检：本地有什么、缺什么、版本是否对得上地图
```

缺源码时才运行下载；**目标名可以收窄，别动辄全量拉**：

```bash
./bootstrap.sh                                     # 下载缺失的全部 + 挂载地图，可重复运行
./bootstrap.sh afnetworking jsonmodel yymodel sdwebimage # 只补四份第三方库
./bootstrap.sh swift-foundation gnustep             # 只补通知中心相关的两份（约 40 MB）
```

会被下载到工作区的十一个目录：

- **Apple 底层六份**：`new objc4/` `CF-1153.18-apple/` `libdispatch-apple/` `libdispatch/`
  `swift-corelibs-foundation/` `swift-foundation/`
- **参照实现一份**：`gnustep-base/`（**非 Apple 代码**，补 Apple 从未开源的 Foundation ObjC
  实现，主要是 `NSNotificationCenter` 与 KVO；约 12 MB，可单独补：`./bootstrap.sh gnustep`）
- **第三方库四份**，都在 `third-party/` 下：`AFNetworking/` `JSONModel/` `YYModel/` `SDWebImage/`
  （合计约 75 MB，可单独补：`./bootstrap.sh afnetworking jsonmodel yymodel sdwebimage`）

首次全量约 2–3 GB、耗时较长，**必须先告知用户再执行**，不要在回答问题的中途默默拉一遍。
`bootstrap.sh` 下载前会核对本地：已有的不会重复下载；版本与地图基准不一致时**只提示不自动切**，
这种情况要把它的提示原样转达用户，不要自作主张执行 checkout——切版本会让地图里的行号全部失效。

## 规范一：先更新源码，再回答

只要问题涉及 objc runtime / RunLoop / CoreFoundation / GCD / Foundation / 通知中心 / KVO /
AFNetworking / JSONModel / YYModel / SDWebImage，无论看起来多简单：

1. 先运行 `./check-updates.sh`，**按退出码决定下一步**；
2. 再 grep / 读实际源码得结论；
3. 引用带 `文件:行号`，并注明版本（commit / drop 号）。

**不要直接跑 `update-sources.sh`**，它会拉一大段 fetch 日志进上下文。

| 退出码 | 输出开头 | 该做什么 |
|---|---|---|
| 0 | `UPTODATE` | 直接读源码，**不要**跑 update-sources.sh |
| 10 | `UPDATE` | 跑 `./update-sources.sh` 再读 |
| 2 | `ERROR` | 先申请网络权限，用完全相同的参数重跑一次 `check-updates.sh`；重跑仍返回 2 才视为「未能更新」 |

首次检查返回退出码 2 时，可能只是 agent 沙箱无法访问网络或本机代理。agent **必须申请沙箱外网络权限后重跑一次同一条 `check-updates.sh` 命令**，不得改用手动 `git fetch`、`git pull` 或 `git ls-remote` 绕过脚本。只有获得网络权限后的重跑仍返回 2，才声明基于本地版本作答。

两个脚本都接受目标名收窄范围：`objc4` / `libdispatch` / `libdispatch-apple` / `foundation` /
`swift-foundation` / `cf` / `gnustep` / `afnetworking` / `jsonmodel` / `yymodel` / `sdwebimage`，
如 `./check-updates.sh sdwebimage`。其余参数见脚本 `-h`。

四份第三方库与 `gnustep` 钉在具体 release tag 上（地图行号按该 tag 写），策略同 objc4：**有新版本只出 `NOTICE`、不改工作区**，
不要因为看到 NOTICE 就去跑 `update-sources.sh`，也不要自行 `git checkout` 升版——升版会让地图里全部行号失效。

**禁止凭记忆回答。** CF 停更在 10.13、两份 CF 有差异、libdispatch 有两套、objc4 每 drop 都在变、
Foundation 被拆成 corelibs 外壳 + swift-foundation 实现体——凭印象几乎必错。
第三方库同理：AFNetworking 4.x 与 2.x 是两套实现（**4.x 没有常驻 RunLoop 线程**）、SDWebImage 5.x 全面协议化，YYModel 与 JSONModel 也是两套独立实现，
按博客记忆回答几乎必错。

例外：用户明说「不用更新」「就用本地这份」；或同一轮对话中刚检查过。
更新失败时**必须声明**「基于本地 X 版本、未能更新」再作答。

## 规范二：教学提示词渐进式路由

当用户请求「讲解」「学习」「原理」「为什么」或源码分析时，**按下面的顺序**执行：

1. 照规范一核对源码版本。
2. 照下面「按任务定位」表选中目标仓库，读该仓库的 `AGENTS.md` 地图拿到文件名与行号（规范三）。
3. 读取并遵循 [`prompts/teaching/INDEX.md`](./prompts/teaching/INDEX.md)。
4. 用户未指定其他已注册方法或风格时，使用索引声明的默认教学方法。
5. 只读取索引为本次讲解选中的提示词文件，不要扫描或一次性读入整个提示词目录。

**前两步不能跳，也不能挪到后面。** 教学提示词决定「怎么讲」，规范一与规范三决定「讲的内容
从哪来、准不准」。顺序反了就会拿着正确的讲法去裸读源码，既烧上下文又容易漏掉地图里
已经标好的坑。

> **两次实测教训**（就是本文件开头那条「指针会被自动注入架空」的由来）：
> - 第一次：`CLAUDE.md` 把本规范写成「必须」、把 `AGENTS.md` 写成「按需」，冷启动 agent
>   直接跳过整个 `maps/` 层裸读源码，答案侥幸对了，但跳过了版本核对，还多花一次读取去撞
>   「corelibs 里没有 NotificationCenter」这个地图早已标注的坑。
> - 第二次：把 `CLAUDE.md` 的措辞加硬到「第 1 步不能跳」后重测，agent **仍然**先读教学索引、
>   仍然没读 `AGENTS.md`，开销反而从 16 次工具调用涨到 24 次。
>   加硬措辞解决不了，才改成现在的符号链接方案。

## 规范三：渐进式披露，防止上下文溢出

**不要一次性读入整个源码树，也不要通读大文件。**

1. 先看下面的「按任务定位」表，确定目标仓库；
2. 读那个仓库的 `AGENTS.md`（每份 200 行内），拿到文件名和行号；
3. 用 `Read` 的 `offset`/`limit` 只读需要的那几十行，或用 `grep -n` 精确定位。

`CFRunLoop.c` 3955 行、`queue.c` 9085 行、`CFString.c` 6570 行——整读任何一个都会挤爆上下文。
`gnustep-base/Source/` 共 20 万行、`swift-foundation/Sources/` 共 13.8 万行，同样按行号跳读。
第三方库体量小得多（`third-party/` 合计约 5 万行），但同样按地图给的行号跳读，别整目录展开。

---

## 按任务定位

| 问题涉及 | 去读 | 说明 |
|---|---|---|
| RunLoop 循环 / 保活 / mode / source / timer / observer | [`CF-1153.18-apple/AGENTS.md`](./CF-1153.18-apple/AGENTS.md) | RunLoop 权威实现，符号行号表 |
| CF 对象模型 / 集合 / 字符串 / plist / Bundle | 同上 | 按主题分组的文件表 |
| GCD 队列 / async / sync / group / semaphore / once / source | [`libdispatch-apple/AGENTS.md`](./libdispatch-apple/AGENTS.md) | macOS 真实实现，**优先用这份** |
| `dispatch_workgroup` / `eventlink` / 实时线程调度 | 同上 | 仅 Apple drop 有 |
| GCD 的 Linux/Windows 实现、跨平台差异 | [`libdispatch/AGENTS.md`](./libdispatch/AGENTS.md) | Swift 开源版 |
| Foundation（Swift 层）/ 10.13 后 CF 的新增 | [`swift-corelibs-foundation/AGENTS.md`](./swift-corelibs-foundation/AGENTS.md) | 只剩 ObjC 兼容外壳，实现体在下一行 |
| Foundation 核心实现 / `NotificationCenter` 现在怎么存与分发 / Calendar / URL / JSON | [`swift-foundation/AGENTS.md`](./swift-foundation/AGENTS.md) | corelibs 的实现体，**追 main，行号会漂** |
| **通知中心**（observer 表 / post 分发 / 通知队列）、**KVO 动态子类** | [`gnustep-base/AGENTS.md`](./gnustep-base/AGENTS.md) | **非 Apple 代码**，但 Apple 侧这两块一行源码都没有 |
| 类实现化 / category / ivar / isa / 引用计数 / msgSend | [`new objc4/AGENTS.md`](./new%20objc4/AGENTS.md) | 索引，含 6 份子模块地图 |
| 自动释放池、RunLoop 与 GCD 主队列的咬合 | 本文「跨仓库交叉点」一节 | 跨仓库，留在这里 |
| AFNetworking：session 封装 / 序列化 / SSL Pinning / task swizzle / 图片下载 | [`third-party/AFNetworking/AGENTS.md`](./third-party/AFNetworking/AGENTS.md) | 4.0.1，**只有 NSURLSession 一条路径**。索引，含 4 个模块 |
| JSONModel：属性内省 / JSON↔Model 映射 / 类型转换 | [`third-party/JSONModel/AGENTS.md`](./third-party/JSONModel/AGENTS.md) | 1.8.0，objc runtime 的应用样本。索引，含 4 个模块 |
| YYModel：类元数据缓存 / JSON↔Model 映射 / 容器泛型 | [`third-party/YYModel/AGENTS.md`](./third-party/YYModel/AGENTS.md) | 1.0.4，独立于 JSONModel 的 runtime 映射实现 |
| SDWebImage：图片缓存 / 下载调度 / 解码 / 动图 | [`third-party/SDWebImage/AGENTS.md`](./third-party/SDWebImage/AGENTS.md) | 5.21.7，5.x 协议化架构。索引，含 5 个模块 |

第三方库都按源码目录拆分地图：库根的 `AGENTS.md` 只做路由与跨模块串联，符号表在各模块目录自己的 `AGENTS.md` 里。
**先读库根索引，再按它的表选中一个模块**，不要一次读多份模块文档。

---

## 目录总览

| 目录 | 内容 | 版本 |
|---|---|---|
| `new objc4/` | ObjC runtime | 分支 `objc4-951.7` |
| `CF-1153.18-apple/` | CoreFoundation，**RunLoop 权威版** | 分支 `main` @ `CF-1153.18`（macOS 10.13.6，上游已停更） |
| `libdispatch-apple/` | GCD，**macOS drop** | tag `libdispatch-1542.100.32`（detached HEAD） |
| `libdispatch/` | GCD，Swift 开源版 | main |
| `swift-corelibs-foundation/` | Swift CF + Foundation 的 **ObjC 兼容外壳** | main |
| `swift-foundation/` | Foundation **实现体**（`FoundationEssentials` 等） | main |
| `gnustep-base/` | **参照实现**，非 Apple 代码：NSNotificationCenter / KVO / Foundation ObjC 层 | tag `base-1_31_1`（同名本地分支） |
| `third-party/AFNetworking/` | 网络库，按 核心 / UIKit / 测试 分模块 | tag `4.0.1`（同名本地分支） |
| `third-party/JSONModel/` | JSON 模型映射，按 核心 / 转换 / 网络（废弃）分模块 | tag `1.8.0`（同名本地分支） |
| `third-party/YYModel/` | JSON 模型映射，按元数据 / 映射 / 测试分模块 | tag `1.0.4`（同名本地分支） |
| `third-party/SDWebImage/` | 图片加载与缓存，按 Core / Private / MapKit / 测试 分模块 | tag `5.21.7`（同名本地分支） |
| `maps/` | 上面所有目录里全部源码地图的**真身**，本仓库唯一版本管理的正文 | 跟随本仓库 |

第三方库集中放在 `third-party/` 一个文件夹里，与 Apple 源码的顶层目录区分开；
每份都是独立 git 仓库，同样 `.gitignore`、同样由 `bootstrap.sh` 克隆。

## 选型铁律

研究 **iOS/macOS 真实行为**时：

- CoreFoundation → **`CF-1153.18-apple/`**（不是 swift-corelibs）
- GCD → **`libdispatch-apple/`**（不是 `libdispatch/`）

Swift 开源版含大量 Linux/Windows 适配，行号和实现都对不上真实二进制；差异明细见各自 `AGENTS.md`。
反过来，查「10.13 之后 CF 怎么演进的」只能看 swift-corelibs——Apple 已停止开源 CF。

**GNUstep 单独一条铁律**：`gnustep-base/` 是社区独立重实现，**不是 Apple 代码**。
只在 Apple 侧根本没有源码时才用（通知中心、KVO 动态子类），且引用必须写成
「GNUstep base 1.31.1 的实现是……」，**不得表述为「Apple 的实现」**。
RunLoop 和自动释放池 Apple 侧有权威源码（`CF-1153.18-apple/` 与 `new objc4/`），**一律不用 GNUstep 那两份**。

---

## 跨仓库交叉点

三处咬合，只在这里记，子文件不重复。

### 1. CF ←→ GCD：主队列被主 RunLoop 抽干

也是「主 RunLoop 不需要保活」的根因：

- `CF-1153.18-apple/CFRunLoop.c:58-69` —— CF 声明 GCD 后门符号 `_dispatch_get_main_queue_port_4CF` / `_dispatch_main_queue_callback_4CF`
- `CFRunLoop.c:838` —— `__CFRunLoopModeIsEmpty` 中主 RunLoop + common mode 直接 `return false`，注释 `// represents the libdispatch main queue`
- `CFRunLoop.c:2344` —— **同一个条件**决定是否监听 dispatch 端口
- `CFRunLoop.c:1590` —— 收到消息后回调进 GCD
- `libdispatch-apple/src/queue.c:8367` —— GCD 侧落点（Swift 版在 `libdispatch/src/queue.c:7082`）

一句话：`dispatch_async(main_queue)` 不是 GCD 自己跑的，是主 RunLoop 收到 mach 消息后回调 GCD 执行的。

### 2. CF ←→ objc4：自动释放池

- `new objc4/runtime/NSObject.mm:2270` `_objc_autoreleasePoolPush` / `:2276` `_objc_autoreleasePoolPop`
- 主 RunLoop 注册的 observer：`Entry` → push；`BeforeWaiting` → pop 后 push；`Exit` → pop
- 回调路径 `CF-1153.18-apple/CFRunLoop.c:1668` `__CFRunLoopDoObservers`
- 注意：注册这些 observer 的代码在 **UIKit/Foundation**，不在本工作区，只能靠符号断点观察

### 3. GCD ←→ objc4

`libdispatch-apple/src/object.m`、`os/object.h` 的 `OS_OBJECT_USE_OBJC` 决定 dispatch 对象是否是真 ObjC 对象（能否 ARC 管理）。对照 objc4 的 `isa` 布局看。

### 4. Foundation 的两半：corelibs 外壳 ←→ swift-foundation 实现体

查 `NotificationCenter` 时最容易踩空的一条链——在 corelibs 里 `grep "class NotificationCenter"` 零命中：

- `swift-corelibs-foundation/Sources/Foundation/NSNotification.swift:93` —— `post(_:)`，函数体只有一行
- `:94` —— 转调 `_post(notification.name.rawValue, subject:message:)`
- **落点** `swift-foundation/Sources/FoundationEssentials/NotificationCenter/NotificationCenter.swift:118`
- 类本体与全部状态：同文件 `:79` 的 `open class NotificationCenter`，状态只有 `:80` 一个 `registrar` 字段
- 接缝一律带 `@_spi(SwiftCorelibsFoundation)` 标记，**认这个标记就能找到所有跨仓库调用**
- 依赖声明在 `swift-corelibs-foundation/Package.swift:166`

同一个问题的另一种解法在 `gnustep-base/Source/NSNotificationCenter.m:244`（三张独立表），
对照读能看清「两级字典 + 通配 nil 键」与「wildcard/nameless/named 三表」的取舍。

### 5. 第三方库 ←→ 底层

第三方库的价值在于「底层机制的真实用法」，讲解时优先打通这几条线，不要就库论库：

- **JSONModel ←→ objc4**：`JSONModel.m:530` `__inspectProperties` 用 `class_copyPropertyList` /
  `property_getAttributes` 解析类型编码，结果用 `objc_setAssociatedObject` 挂在类对象上。
  类型编码的定义在 `new objc4/runtime/`，关联对象实现见 `new objc4/runtime/objc-references.mm`。
- **YYModel ←→ objc4 / GCD**：`YYClassInfo.m:273` 枚举类的 method/property/ivar 元数据，
  `:329` 用 `dispatch_once` + semaphore 缓存；映射元数据在 `NSObject+YYModel.m:478` 组合。
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

目标：`objc4` / `libdispatch` / `libdispatch-apple` / `foundation` / `swift-foundation` / `cf` /
`gnustep` / `afnetworking` / `jsonmodel` / `yymodel` / `sdwebimage`。三种策略：

| 目标 | 策略 | 原因 |
|---|---|---|
| `objc4`、`gnustep`、`afnetworking`、`jsonmodel`、`yymodel`、`sdwebimage` | 只 fetch，报告有无新版本，**永不动工作区** | 钉在指定 tag，地图行号按该 tag 写 |
| `libdispatch`、`foundation`、`swift-foundation`、`cf` | `merge --ff-only` | 干净的 tracking 分支 |
| `libdispatch-apple` | 自动 checkout 到版本号最高的 tag | drop 代码在 tag 上，`main` 常落后 |

要给第三方库升版，得**同时**改 `sources.sh` 里的 ref 和对应地图里的全部行号，属于人工任务，agent 不要自作主张。

## 三个脚本与一份清单

| 文件 | 作用 |
|---|---|
| `sources.sh` | 源码清单（目标名 / 目录 / 上游 / 策略 / ref / clone 参数 / tag 过滤 glob），**三个脚本共用的唯一事实来源** |
| `bootstrap.sh` | 下载源码（下载前核对本地）+ 挂载地图 |
| `check-updates.sh` | 只读探测，秒级、带缓存 |
| `update-sources.sh` | 执行更新，只动已下载的源码 |

对 agent 有意义的三条：

- 三个脚本的目标名完全一致，都来自清单；打错目标名会立刻报错并列出可用值。
- 源码目录一律不进本仓库，`bootstrap.sh` 每轮用 `git check-ignore` 复核；**任何时候都不要把源码 `git add` 进来**。
- 新增源码只改 `sources.sh` 一行，不要再去三个脚本里各抄一份。完整用法见 [`README.md`](./README.md) 的「脚本使用说明」。
- 仓库里混着非版本号的历史 tag 时，清单末尾的 **tag 过滤 glob** 必须填（`gnustep` 填的是 `base-*`），
  否则 `sort -V` 会把 `start-cvs` 这类排到最高，每轮检查都报一条永远消不掉的假「有新版本」。

安全约束：工作区脏默认跳过（`-f` 才 stash）；本地领先上游判为分叉只报告；只用 `--ff-only`。fetch 失败自动重试 3 次。

CF 的仓库是 `apple-oss-distributions/CF`，`main` 停在 `CF-1153.18`（2021 年最后一次 push），实际不会再有更新；留着 git 主要是为了能 `git diff CF-1151.16 CF-1153.18` 对照历史版本。

---

## 工作约定

- 十一份源码都是**只读研究**，不追求可构建（objc4 需 internal SDK，CF 是精简包缺文件，gnustep-base 需 gnustep-make + libobjc2；四份第三方库理论上可构建，但本工作区不做这件事）。
- 十一个源码目录都是独立 git 仓库，不做 submodule，一律 `.gitignore`（第三方库整个 `/third-party/` 被忽略），互不干扰。
- **地图的真身在 `maps/`**，源码树里那些 `AGENTS.md` / `CLAUDE.md` 都是指向它的符号链接（`bootstrap.sh` 挂的）。
  就地编辑 `new objc4/runtime/AGENTS.md` 等于编辑 `maps/new objc4/runtime/AGENTS.md`，改动自动进入本仓库的 `git status`——**记得提交**。
- **正文一律在 `AGENTS.md`，`CLAUDE.md` 只是三行指针**，各地图目录无一例外。读地图直接读 `AGENTS.md`，
  不要两份都读——`CLAUDE.md` 里没有任何独有内容。
- 这些链接同时写进了各子仓库的 `.git/info/exclude`，不污染子仓库 `git status`，也就不会让更新脚本因「工作区脏」跳过合并。
- 新增地图时**必须写进 `maps/` 再跑 `./bootstrap.sh --maps-only` 挂载**；直接在源码树里新建文件会成为游离的未跟踪文件，别人 clone 不到。
- 引用代码带 `文件:行号` + 版本号；三个追 main 的仓库（`libdispatch`、`swift-corelibs-foundation`、
  `swift-foundation`）会随更新变动，**必须同时记 commit**。`gnustep-base` 钉在 `base-1_31_1`，写 tag 即可。
  第三方库钉在 tag，引用写成 `AFURLSessionManager.m:210`（AFNetworking 4.0.1）这样即可。
- SDWebImage 的 `Core/` 与 `include/SDWebImage/` 是同一份头文件的两个副本，grep 结果会翻倍，**行号一律引 `Core/`**。
- 缩进跟随各仓库原有风格（objc4 是 4 空格，与用户全局 OC 的 2 空格规范不同）。
