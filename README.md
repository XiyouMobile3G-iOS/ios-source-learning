# iOS 底层源码学习工作区

给 **AI agent** 用的 Apple 底层源码导航层：objc runtime、CoreFoundation（RunLoop）、libdispatch（GCD）、Foundation。

本仓库**不搬运 Apple 源码**，只提供三样东西——而这三样恰恰是"下载了源码却读不动"的真正卡点：

| 提供什么 | 解决什么问题 |
|---|---|
| **一套手写的源码地图**（`notes/`，22 份、含符号与行号） | `CFRunLoop.c` 3955 行、`queue.c` 9085 行，整读会挤爆 agent 上下文；地图让它直接跳到那几十行 |
| **一套 agent 行为规范**（`AGENTS.md` / `CLAUDE.md`） | 强制"先核对源码版本再回答"，杜绝 LLM 凭记忆编 runtime 细节 |
| **一套版本管理脚本**（`bootstrap.sh` / `check-updates.sh` / `update-sources.sh`） | 五份源码分别钉在正确的 drop / 分支上，且能安全跟进上游更新 |

配合 Claude Code、Codex 等能读 `AGENTS.md` 的 agent 使用：**clone → bootstrap → 直接提问**，它会自己找到该读哪个文件的哪一段。

---

## 快速开始

```bash
git clone https://github.com/XiyouMobile3G-iOS/ios-source-learning.git
cd ios-source-learning
./bootstrap.sh
```

`bootstrap.sh` 会克隆五份上游源码到各自正确的 ref，并把 `notes/` 里的笔记以符号链接挂回源码树原位。
**首次约 2–3 GB，视网络需要十几分钟**；可重复运行，已存在的仓库会跳过。

```bash
./bootstrap.sh --check       # 只体检：缺哪个仓库、哪些笔记没挂上
./bootstrap.sh -n            # 演练
./bootstrap.sh objc4 cf      # 只处理指定目标
./bootstrap.sh --notes-only  # 只重挂笔记，不克隆
```

搭好之后，在这个目录里启动你的 agent，直接问就行：

> RunLoop 没有 source/timer 的时候为什么不会退出？
>
> `dispatch_async` 到主队列，最终是谁把 block 跑起来的？
>
> objc 的 `isa` 里那些位分别是什么，arm64 和 x86_64 有什么差别？

Agent 会自动读 `AGENTS.md` → 按「按任务定位」表选中目标仓库 → 读那个仓库的笔记拿到行号 → 只读需要的几十行，并给出带 `文件:行号` + 版本号的回答。

---

## 仓库结构

```
.
├── AGENTS.md            # agent 的总规范与跨仓库索引（人也建议读一遍）
├── CLAUDE.md            # Claude Code 入口，指向 AGENTS.md
├── bootstrap.sh         # 搭建：克隆源码 + 挂载笔记
├── check-updates.sh     # 只读探测：需不需要更新（秒级、带缓存）
├── update-sources.sh    # 执行更新（三种策略，见下）
├── notes/               # ★ 本仓库唯一的正文：22 份源码地图
│   ├── new objc4/                    # 根 + runtime / Messengers / Threading / test / ObjectiveC / objcdt 六份模块记忆
│   ├── CF-1153.18-apple/             # RunLoop 权威实现的符号行号表
│   ├── libdispatch-apple/
│   ├── libdispatch/
│   └── swift-corelibs-foundation/
├── prompts/teaching/    # 教学提示词（渐进式互动讲解 + 面试回答风格）
├── docs/plans/          # 上述提示词的设计与实施记录
│
└── （以下由 bootstrap.sh 克隆，.gitignore 不跟踪）
    new objc4/  CF-1153.18-apple/  libdispatch-apple/  libdispatch/  swift-corelibs-foundation/
```

### 五份源码的定位

| 目录 | 内容 | 钉在哪 |
|---|---|---|
| `new objc4/` | ObjC runtime | tag `objc4-951.7`（笔记行号按此 drop 写） |
| `CF-1153.18-apple/` | CoreFoundation，**RunLoop 权威版** | `main` @ `CF-1153.18`（macOS 10.13.6，上游已停更） |
| `libdispatch-apple/` | GCD，**macOS drop** | 最新 tag（当前 `libdispatch-1542.100.32`） |
| `libdispatch/` | GCD，Swift 开源版 | `main` |
| `swift-corelibs-foundation/` | Swift CF + Foundation | `main` |

**选型铁律**：研究 iOS/macOS 真实行为时，CoreFoundation 看 `CF-1153.18-apple/`、GCD 看 `libdispatch-apple/`。
Swift 开源版含大量 Linux/Windows 适配，行号和实现都对不上真实二进制；反过来查"10.13 之后 CF 怎么演进"只能看 swift-corelibs——Apple 已停止开源 CF。

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

外加一类 `NOTICE`：有新 drop 但脚本按策略不会自动切（objc4），需人工处理，**不改变退出码**——免得 agent 每轮都被驱使去跑一次注定无效的更新。

`update-sources.sh` 对三类仓库用三种策略：

| 目标 | 策略 | 原因 |
|---|---|---|
| `objc4` | 只 fetch、报告新 drop，**永不动工作区** | 笔记行号钉在 951.7，自动升级会让全部行号失效 |
| `libdispatch` / `foundation` / `cf` | `merge --ff-only` | 干净的 tracking 分支 |
| `libdispatch-apple` | 自动 checkout 到版本号最高的 tag | drop 代码在 tag 上，`main` 常落后 |

安全约束：工作区脏默认跳过（`-f` 才 stash）、本地领先上游判为分叉只报告、只用 `--ff-only`、fetch 失败自动重试 3 次。两个脚本都接受目标名收窄范围（`objc4` / `libdispatch` / `libdispatch-apple` / `foundation` / `cf`），`-h` 看完整用法。

> 升级源码后行号会变，**笔记里的行号需要同步校对**——这是 objc4 采取"只报告不自动切"策略的原因。

---

## 贡献笔记

笔记的真身在 `notes/`，源码树里看到的 `AGENTS.md` / `CLAUDE.md` 都是指向它的符号链接。
所以**就地编辑就行**——改 `new objc4/runtime/CLAUDE.md` 等于改 `notes/new objc4/runtime/CLAUDE.md`，改动会直接出现在本仓库的 `git status` 里。

只有一条硬规则：

> **新增**笔记必须先写进 `notes/` 对应位置，再跑 `./bootstrap.sh --notes-only` 挂载。
> 直接在源码树里新建文件会成为游离的未跟踪文件（子仓库把 `AGENTS.md` / `CLAUDE.md` 写进了 `.git/info/exclude`），别人 clone 不到。

笔记的写法约定，照着现有文件抄即可：

- 每份控制在 200 行内，只放**文件表 + 关键符号 + 行号**，不复制源码正文——它的用途是让 agent 少读文件，自己先撑爆上下文就本末倒置了。
- 引用一律 `文件:行号` + 版本号（两个 Swift 仓库随时在动，最好同时记 commit）。
- `CLAUDE.md` 放正文、`AGENTS.md` 只做指针（或反过来），成对存在但**内容不重复**，避免 agent 把两份都读进上下文。

改动源码目录本身没有意义——它们是只读研究对象，`update-sources.sh` 会因"工作区脏"而跳过更新。

---

## 关于源码与许可

本仓库内容为原创的学习笔记与工具脚本；Apple 源码本体不在此处，由 `bootstrap.sh` 从各自上游仓库拉取，其许可以上游为准（objc4 / CF / libdispatch 的 Apple drop 遵循 APSL，swift-corelibs-* 遵循 Apache-2.0）。

上游地址：

- https://github.com/apple-oss-distributions/objc4
- https://github.com/apple-oss-distributions/CF
- https://github.com/apple-oss-distributions/libdispatch
- https://github.com/apple/swift-corelibs-libdispatch
- https://github.com/apple/swift-corelibs-foundation

---

本仓库地址：<https://github.com/XiyouMobile3G-iOS/ios-source-learning>
