# iOS 源码学习工作区

给 **AI agent** 用的源码导航层，覆盖三类：

- **Apple 底层**：objc runtime、CoreFoundation（RunLoop）、libdispatch（GCD）、Foundation（外壳 + 实现体两份）
- **参照实现**：GNUstep base——Apple 从未开源 Foundation 的 ObjC 实现，`NSNotificationCenter`、KVO 只能看它
- **常用第三方库**（都在 `third-party/` 一个文件夹里）：AFNetworking、JSONModel、YYModel、SDWebImage

本仓库**不搬运任何源码**，只提供三样东西——而这三样恰恰是"下载了源码却读不动"的真正卡点：

> **先说清 `maps/` 是什么**：它是**人手写的、给 AI 读的源码导航索引**，不是学习笔记。
> 内容形态是「文件表 + 关键符号 + 行号」，目的是让 agent 跳过检索直接读到那几十行。
> 理解、推导、心得这类内容**不属于这里**——写进去就会挤占 agent 的上下文预算，
> 与这套东西存在的理由正好相反。（目录早先叫 `notes/`，名字误导，已改。）

| 提供什么 | 解决什么问题 |
|---|---|
| **一套手写的源码地图**（`maps/`，62 份、按模块划分、含符号与行号） | `CFRunLoop.c` 3955 行、`queue.c` 9085 行，整读会挤爆 agent 上下文；地图让它直接跳到那几十行 |
| **一套 agent 行为规范**（`AGENTS.md` / `CLAUDE.md`） | 强制"先核对源码版本再回答"，杜绝 LLM 凭记忆编 runtime 细节，或拿 AFNetworking 2.x 的博客结论讲 4.x |
| **一套版本管理脚本**（`sources.sh` 清单 + `bootstrap.sh` / `check-updates.sh` / `update-sources.sh`） | 十一份源码分别钉在正确的 drop / tag / 分支上，下载前先核对本地、能安全跟进上游更新 |

配合 Claude Code、Codex 等能读 `AGENTS.md` 的 agent 使用：**clone → bootstrap → 直接提问**，它会自己找到该读哪个文件的哪一段。

---

## 快速开始

```bash
git clone https://github.com/XiyouMobile3G-iOS/ios-source-learning.git
cd ios-source-learning
./bootstrap.sh
```

`bootstrap.sh` 会把十一份上游源码下载到各自正确的 ref，并把 `maps/` 里的地图以符号链接挂回源码树原位。
**首次约 2–3 GB，视网络需要十几分钟**；可重复运行，**已经下载过的不会重复拉**。

完整用法见下面的[脚本使用说明](#脚本使用说明)。

搭好之后，在这个目录里启动你的 agent，直接问就行：

> RunLoop 没有 source/timer 的时候为什么不会退出？
>
> `dispatch_async` 到主队列，最终是谁把 block 跑起来的？
>
> objc 的 `isa` 里那些位分别是什么，arm64 和 x86_64 有什么差别？
>
> AFNetworking 4.x 的回调为什么一定回到主线程？序列化又在哪个队列做？
>
> JSONModel 是怎么知道一个属性是可选的、数组里该装哪个类的？
>
> SDWebImage 的「后进先出」是队列自带的吗？

Agent 会自动读 `AGENTS.md` → 按「按任务定位」表选中目标仓库 → 读那个仓库的地图拿到行号 → 只读需要的几十行，并给出带 `文件:行号` + 版本号的回答。

---

## 仓库结构

```
.
├── AGENTS.md            # agent 的总规范与跨仓库索引（人也建议读一遍）
├── CLAUDE.md            # → AGENTS.md 的符号链接（同一个文件，两个自动加载入口）
├── sources.sh           # ★ 源码清单：三个脚本共用的唯一事实来源
├── progress.sh          # git clone / fetch 进度条
├── bootstrap.sh         # 搭建：下载源码（先核对本地）+ 挂载地图
├── check-updates.sh     # 只读探测：需不需要更新（秒级、带缓存）
├── update-sources.sh    # 执行更新（三种策略，见下）
├── maps/                # ★ 本仓库唯一的正文：62 份源码地图（正文一律在 AGENTS.md）
│   ├── new objc4/                    # 根 + runtime / Messengers / Threading / test / ObjectiveC / objcdt 六份模块地图
│   ├── CF-1153.18-apple/             # RunLoop 权威实现的符号行号表
│   ├── libdispatch-apple/
│   ├── libdispatch/
│   ├── swift-corelibs-foundation/    # ObjC 兼容外壳
│   ├── swift-foundation/             # Foundation 实现体，含 NotificationCenter 全表
│   ├── gnustep-base/                 # 参照实现：NSNotificationCenter / KVO（非 Apple 代码）
│   └── third-party/                  # 第三方库地图，每份都是「库根索引 + 模块文档」两级
│       ├── AFNetworking/             # 索引 + 核心 / UIKit / 测试
│       ├── JSONModel/                # 索引 + 核心 / 转换 / 网络（废弃）
│       ├── YYModel/                  # 索引 + 核心 / 测试
│       └── SDWebImage/               # 索引 + Core / Private / MapKit / 测试
├── prompts/teaching/    # 教学提示词（渐进式互动讲解 + 面试回答风格）
├── docs/plans/          # 上述提示词的设计与实施记录
│
└── （以下由 bootstrap.sh 克隆，.gitignore 不跟踪）
    new objc4/  CF-1153.18-apple/  libdispatch-apple/  libdispatch/  swift-corelibs-foundation/
    swift-foundation/  gnustep-base/
    third-party/AFNetworking/  third-party/JSONModel/  third-party/YYModel/  third-party/SDWebImage/
```

### 六份 Apple 源码的定位

| 目录 | 内容 | 钉在哪 |
|---|---|---|
| `new objc4/` | ObjC runtime | tag `objc4-951.7`（地图行号按此 drop 写） |
| `CF-1153.18-apple/` | CoreFoundation，**RunLoop 权威版** | `main` @ `CF-1153.18`（macOS 10.13.6，上游已停更） |
| `libdispatch-apple/` | GCD，**macOS drop** | 最新 tag（当前 `libdispatch-1542.100.32`） |
| `libdispatch/` | GCD，Swift 开源版 | `main` |
| `swift-corelibs-foundation/` | Swift CF + Foundation 的 **ObjC 兼容外壳** | `main` |
| `swift-foundation/` | Foundation **实现体**（`FoundationEssentials` / `FoundationInternationalization`） | `main` |

后两份必须成对读：corelibs 里 `NotificationCenter.post(_:)` 只有一行转调，类本体在 `swift-foundation`。
跨仓库接缝一律带 `@_spi(SwiftCorelibsFoundation)` 标记。

### 一份参照实现的定位

| 目录 | 内容 | 钉在哪 |
|---|---|---|
| `gnustep-base/` | GNUstep base，OpenStep/Cocoa 的**独立开源重实现**（LGPL，社区维护） | tag `base-1_31_1` |

**它不是 Apple 的代码。** 收进来只因为一件事：Apple 从未开源过 Foundation 的 Objective-C 实现，
`NSNotificationCenter` 怎么存 observer、KVO 的动态子类怎么生成，Apple 侧一行源码都没有
（CF 里的 `CFUserNotification.c` 是弹系统对话框的，同名但无关）。
所以它的定位是**参照实现**：行为按 OpenStep 规范对齐，实现细节不保证与 Apple 一致，
引用时必须注明「GNUstep base 1.31.1」。RunLoop、自动释放池这类 Apple 侧有权威源码的，一律不用这份。

### 四份第三方库的定位

四份都集中在 `third-party/` 一个文件夹里，与 Apple 源码的顶层目录分开，各自是独立 git 仓库。

| 目录 | 内容 | 钉在哪 |
|---|---|---|
| `third-party/AFNetworking/` | 网络库。**4.x 只剩 `NSURLSession` 一条路径，没有常驻 RunLoop 线程**（那是 2.x） | tag `4.0.1` |
| `third-party/JSONModel/` | JSON↔Model 映射。全库仅 3350 行，是 objc runtime 属性内省的教科书样本 | tag `1.8.0` |
| `third-party/YYModel/` | JSON↔Model 映射。类/属性元数据缓存与容器泛型实现 | tag `1.0.4` |
| `third-party/SDWebImage/` | 图片加载与缓存。5.x 缓存/加载/编解码全部协议化 | tag `5.21.7` |

**它们钉在具体 release tag 上**，理由和 objc4 一样：地图里的行号按该 tag 写，自动升版会让行号全部失效。
所以 `update-sources.sh` 对这四份只 fetch、只报告，不改工作区；升版是人工任务（改 `sources.sh` 里的 ref + 校对地图行号）。

**选型铁律**：研究 iOS/macOS 真实行为时，CoreFoundation 看 `CF-1153.18-apple/`、GCD 看 `libdispatch-apple/`。
Swift 开源版含大量 Linux/Windows 适配，行号和实现都对不上真实二进制；反过来查"10.13 之后 CF 怎么演进"只能看 swift-corelibs——Apple 已停止开源 CF。

---

## 脚本使用说明

一个清单、三个脚本、一份进度条：

| 文件 | 作用 |
|---|---|
| `sources.sh` | **源码清单，唯一事实来源**。本身不做事，被三个脚本 `source` 进去 |
| `progress.sh` | git clone / fetch 的进度条，被 `bootstrap.sh` 和 `update-sources.sh` source |
| `bootstrap.sh` | 下载源码 + 挂载地图（搭工作区） |
| `check-updates.sh` | 只读探测：需不需要更新（秒级、带缓存） |
| `update-sources.sh` | 执行更新（只动已下载的源码） |

三个脚本的目标名、目录、上游地址、更新策略**全部来自 `sources.sh`**，
所以加一份源码只改那里一行，不会出现「改了下载脚本忘了改更新脚本」。全部支持 `-h`。

### `bootstrap.sh`：下载源码

```bash
./bootstrap.sh                 # 下载缺的 + 挂载地图（可重复运行）
./bootstrap.sh sdwebimage      # 只处理指定目标
./bootstrap.sh objc4 cf        # 多个目标
./bootstrap.sh --check         # 只体检：本地有什么、缺什么、链接是否完好，不改动
./bootstrap.sh -n              # 演练，只报告不改动
./bootstrap.sh --maps-only     # 只重挂地图，不下载（旧名 --notes-only 仍可用）
```

终端里下载会画一条进度条，把当前仓库的 git 传输百分比叠到「第几个仓库」上，例如
`[████░░░░]  30%  objc4  2/10  下载  120.4 MiB | 3.1 MiB/s`。
非终端默认不画自定义进度条，`bootstrap.sh` 和 `update-sources.sh` 都使用 `--quiet`，
避免把批量下载或 fetch 的进度混入普通日志；设置测试用的 `PROGRESS_FORCE` 时，
非终端也会画自定义进度条。

**下载前会先核对本地**，这也是它可以随便重复跑的原因：

| 本地情况 | 脚本行为 |
|---|---|
| 没有该目录 | 下载，并切到清单指定的 ref |
| 已有且是对的仓库、对的版本 | ✓ 跳过下载，直接挂地图 |
| 已有但版本与地图基准不一致 | ! 报出实际版本，**给出对齐命令但不自动切**（切了地图行号就废了） |
| 已有但 `origin` 指向别的仓库 | ✗ 停下不动它，提示先移走该目录（SSH 与 HTTPS 视为同一仓库） |
| 目录存在但不是 git 仓库 | ✗ 停下不动它，交人工判断 |

**源码不会进入本仓库**：八个源码目录都由 `.gitignore` 忽略，脚本每轮还会用 `git check-ignore`
逐个复核，漏了会告警并给出该补的那行。所以在工作区里 `git add -A` 也不会把 2–3 GB 源码提交进来。

### `check-updates.sh`：先探测

```bash
./check-updates.sh          # 一行结论（带 6h 缓存）
./check-updates.sh -v       # 逐仓库列出本地/远端版本
./check-updates.sh -f       # 忽略缓存，强制走网络
./check-updates.sh cf       # 只查指定目标
```

只用 `git ls-remote` 读远端 refs，**不 fetch、不写 `.git`、不碰工作区**，输出极简以省 agent 上下文。
退出码见下一节。源码没下载时它会直接告诉你去跑 `./bootstrap.sh <目标>`。

### `update-sources.sh`：再执行

```bash
./update-sources.sh                        # 全部
./update-sources.sh libdispatch cf         # 指定目标
./update-sources.sh -n                     # 演练
./update-sources.sh -f                     # 允许 stash 后更新脏工作区
```

**只更新已经下载过的源码**；没下载的会提示去跑 `bootstrap.sh`，不会顺手替你下载。
使用 `-n` 演练时不会执行 fetch，脚本只展示将执行的命令；该目标仍按一次成功处理，
因此摘要和进度计数用于演练展示，不代表实际网络传输。

### 加一份新源码

在 `sources.sh` 的 `SOURCES` 里加一行，字段是
`目标名|目录名|显示名|上游 URL|策略|ref|clone 附加参数|tag 过滤 glob`：

```bash
"yykit|third-party/YYKit|YYKit|https://github.com/ibireme/YYKit.git|pinned|1.0.9|"
```

策略三选一：`pinned`（钉 tag，只报告不自动切）、`track`（追分支，ff-only）、`latest`（追最新 tag，自动切）。

末两个字段可省略：

- **clone 附加参数**：历史体量大的仓库填 `--filter=blob:none`（只把历史里的 blob 留在远端，
  工作区文件仍然是齐的，离线读源码不受影响）。
- **tag 过滤 glob**：仓库里混着非版本号的历史 tag 时**必须填**，否则 `sort -V` 会把它们排到最高，
  每次 `check-updates.sh` 都报一条永远消不掉的假「有新版本」。
  `gnustep-base` 就是这样——它有 1998 年的 `start-cvs` 和一堆 `snapshot-9808xx`，
  真正的发布 tag 只有 `base-*`，所以那行填了 `base-*`。

然后在 `.gitignore` 确认该目录被忽略，跑 `./bootstrap.sh yykit` 即可——三个脚本都会自动认识它。

---

## 更新机制

日常只需要两条命令，**先探测、后执行**：

```bash
./check-updates.sh -v      # 只读远端 refs，不 fetch、不碰工作区，几秒返回
./update-sources.sh        # 仅在上一步说要更新时才跑
```

`check-updates.sh` 的退出码是给 agent 判断用的：

| 退出码 | 输出开头 | 含义 |
|---|---|---|
| 0 | `UPTODATE` | 直接读源码，**不要**跑 `update-sources.sh` |
| 10 | `UPDATE` | 跑 `./update-sources.sh` 再读 |
| 2 | `ERROR` | 按"未能更新"处理，声明基于本地版本后作答 |

外加一类 `NOTICE`：有新版本但脚本按策略不会自动切（objc4、gnustep 与四份第三方库），需人工处理，**不改变退出码**——免得 agent 每轮都被驱使去跑一次注定无效的更新。

`update-sources.sh` 对三类仓库用三种策略：

| 目标 | 策略 | 原因 |
|---|---|---|
| `objc4` / `gnustep` / `afnetworking` / `jsonmodel` / `yymodel` / `sdwebimage` | 只 fetch、报告新版本，**永不动工作区** | 钉在指定 tag，自动升级会让地图里全部行号失效 |
| `libdispatch` / `foundation` / `swift-foundation` / `cf` | `merge --ff-only` | 干净的 tracking 分支 |
| `libdispatch-apple` | 自动 checkout 到版本号最高的 tag | drop 代码在 tag 上，`main` 常落后 |

安全约束：工作区脏默认跳过（`-f` 才 stash）、本地领先上游判为分叉只报告、只用 `--ff-only`、fetch 失败自动重试 3 次。`track` 策略（`libdispatch` / `foundation` / `swift-foundation` / `cf`）还会核对本地当前分支与 `sources.sh` 里配置的 ref：分支不符时 `check-updates.sh` 报 ERROR（退出码 2），`update-sources.sh` 跳过该目标且不 fetch（`-n`/`-f` 不旁路）。两个脚本都接受目标名收窄范围（`objc4` / `libdispatch` / `libdispatch-apple` / `foundation` / `swift-foundation` / `cf` / `gnustep` / `afnetworking` / `jsonmodel` / `yymodel` / `sdwebimage`），`-h` 看完整用法。

> 升级源码后行号会变，**地图里的行号需要同步校对**——这是 objc4 采取"只报告不自动切"策略的原因。

---

## 贡献源码地图

### 先分清写什么、不写什么

`maps/` 的读者是 agent，不是人。它要解决的问题只有一个：**让 agent 用最少的 token 找到该读的那几十行**。
所以内容取舍非常明确：

| 该进 `maps/` | 不该进 `maps/` |
|---|---|
| 文件表、目录结构、各文件行数 | 对某个机制的理解、推导、心得 |
| 关键符号 + 精确行号 | 复制粘贴的源码正文 |
| 「这个仓库权威 / 那个不权威」这类选型判断 | 教程式的展开讲解 |
| 易踩的坑（同名文件、行号对不上、副本目录） | 能从源码直接读出来、无需索引的东西 |

判断标准就一条：**这句话能不能帮 agent 少读一个文件？** 不能就别写。
想写理解和推导是好事，但那属于你自己的笔记本或博客，不属于这个仓库。

### 怎么改

地图的真身在 `maps/`，源码树里看到的 `AGENTS.md` / `CLAUDE.md` 都是指向它的符号链接。
所以**就地编辑就行**——改 `new objc4/runtime/AGENTS.md` 等于改 `maps/new objc4/runtime/AGENTS.md`，改动会直接出现在本仓库的 `git status` 里。

只有一条硬规则：

> **新增**地图必须先写进 `maps/` 对应位置，再跑 `./bootstrap.sh --maps-only` 挂载。
> 直接在源码树里新建文件会成为游离的未跟踪文件（子仓库把 `AGENTS.md` / `CLAUDE.md` 写进了 `.git/info/exclude`），别人 clone 不到。

格式约定，照着现有文件抄即可：

- 每份控制在 200 行内，只放**文件表 + 关键符号 + 行号**，不复制源码正文——它的用途是让 agent 少读文件，自己先撑爆上下文就本末倒置了。
- 引用一律 `文件:行号` + 版本号。三个追 `main` 的仓库（`libdispatch` / `swift-corelibs-foundation` / `swift-foundation`）随时在动，**必须同时记 commit**。
- **`maps/` 下正文一律写在 `AGENTS.md`，`CLAUDE.md` 一律是那三行指针**，各地图目录无一例外，不要反着放。
  理由：`AGENTS.md` 是跨 agent 的通用约定（Codex 等也读），`CLAUDE.md` 是 Claude 专属；
  正文放通用的那份，其他 agent 才不用多跳一次。两份成对存在但**内容不重复**，避免 agent 把两份都读进上下文。
- **但仓库根目录相反**：根 `CLAUDE.md` 是指向 `AGENTS.md` 的**符号链接**，不是指针文件。
  判据是「这个文件会不会被自动注入上下文」：

  | | 加载方式 | 该用什么 |
  |---|---|---|
  | `maps/` 下 28 对 | agent 按需主动读 | 指针可行，且能省上下文 |
  | 仓库根那一对 | Claude Code 自动注入 `CLAUDE.md`，Codex 自动注入 `AGENTS.md` | **必须是符号链接** |

  原因是实测出来的：指针只在「按需读取」时成立。根目录被自动注入时，agent 开局就拿到
  一句「去读另一个文件」，然后直奔任务再不回头——**自动注入这个机制本身会架空指针**。
  两轮冷启动测试都复现了：agent 从不读根 `AGENTS.md`，把措辞加硬到「第 1 步不能跳」也没用，
  开销反而从 16 次工具调用涨到 24 次。改成符号链接后两个入口拿到的是同一份完整正文，
  既根治了问题，也让 drift 在物理上不可能发生。
- **按模块分文件，一个模块目录一对**：仓库根那份只做路由（模块表 + 跨模块链路 + 版本纪律），符号表放到各模块目录自己那份里。
  这样 agent 读完索引就能只取一个模块，而不是把整库的符号表拖进上下文。
- **文件名只能是 `AGENTS.md` / `CLAUDE.md`**：`bootstrap.sh` 只把这两个名字写进子仓库的 `.git/info/exclude`。
  换别的名字会让子仓库 `git status` 变脏，`update-sources.sh` 随即按安全策略跳过更新，更新机制会静默失效。
  所以模块粒度受源码目录结构约束——想再细分，就得先扩展 `bootstrap.sh` 的 `write_exclude`。

改动源码目录本身没有意义——它们是只读研究对象，`update-sources.sh` 会因"工作区脏"而跳过更新。

---

## 关于源码与许可

本仓库内容为原创的源码地图与工具脚本；**源码本体一概不在此处**，由 `bootstrap.sh` 从各自上游仓库拉取，其许可以上游为准
（objc4 / CF / libdispatch 的 Apple drop 遵循 APSL，swift-corelibs-* 与 swift-foundation 遵循 Apache-2.0，
**gnustep-base 遵循 LGPL-2.1+**，AFNetworking / JSONModel / YYModel / SDWebImage 遵循 MIT）。

上游地址：

- https://github.com/apple-oss-distributions/objc4
- https://github.com/apple-oss-distributions/CF
- https://github.com/apple-oss-distributions/libdispatch
- https://github.com/apple/swift-corelibs-libdispatch
- https://github.com/apple/swift-corelibs-foundation
- https://github.com/apple/swift-foundation
- https://github.com/gnustep/libs-base
- https://github.com/AFNetworking/AFNetworking
- https://github.com/jsonmodel/jsonmodel
- https://github.com/SDWebImage/SDWebImage
- https://github.com/ibireme/YYModel

---

## 参与

仓库地址：<https://github.com/XiyouMobile3G-iOS/ios-source-learning>（XiyouMobile3G-iOS 组织，Public）

- **补地图 / 修行号**：按上面「贡献源码地图」的约定改 `maps/` 下对应文件，提 PR
- **加一份新源码**：改 `sources.sh` 一行 + `.gitignore` 确认忽略，见「脚本使用说明」
- **报错或行号对不上**：开 Issue 时请带上版本号（`./check-updates.sh -v` 的输出）与 `文件:行号`

源码升版会让地图里的行号整片失效，所以升版类 PR 请**同时**附上校对后的行号改动。
