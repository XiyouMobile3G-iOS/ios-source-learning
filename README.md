# iOS Source Learning

> 🤖 **给 AI Agent 用的 iOS 源码导航层**
> 31 份手写源码地图（另有 31 个 Claude 入口文件）+ 版本锁定 + 行为规范，让 AI 精确回答 iOS 底层问题

<div align="center">

[![Maps](https://img.shields.io/badge/Source_Maps-31-blue.svg)](maps/)
[![Pinned Versions](https://img.shields.io/badge/Versions-Pinned-green.svg)](#version-coverage)
[![License](https://img.shields.io/badge/License-Mixed-orange.svg)](#license)

</div>

---

## 💡 为什么需要这个项目

### 痛点
- ❌ AI 回答 iOS 底层问题时容易**幻觉**（编造 API、混淆版本）
- ❌ 源码版本不一致导致**行号对不上**、讨论无法复现
- ❌ 缺少导航索引，AI 需要**遍历大量文件**才能定位关键逻辑

### 解决方案
- ✅ **强制版本验证**：通过 `AGENTS.md` 规范，AI 必须先检查版本再回答
- ✅ **精确行号导航**：31 份手写地图预先标注关键符号和行号
- ✅ **一键环境复现**：`bootstrap.sh` 自动下载并锁定所有源码版本

---

## 📦 三大核心资产

### 📍 31 份源码地图
每份地图的正文在 `AGENTS.md`；相同位置的 `CLAUDE.md` 是给 Claude Code 的入口文件，
不重复存放地图内容。两类文件共 62 个，源码地图的统计口径始终是 31 份。

| 类别 | 覆盖范围 | 地图数量 |
|------|---------|---------|
| **Apple 底层** | objc4 (runtime, isa, msgSend, cache_t, ARC)<br>CoreFoundation (RunLoop, CFString)<br>libdispatch (GCD, Queue, Semaphore)<br>Swift Foundation | 12 份 |
| **参考实现** | gnustep-base (NSNotificationCenter, KVO) | 1 份 |
| **三方库** | AFNetworking 4.x, JSONModel, YYModel, SDWebImage 5.x | 18 份 |
| **合计** | 以上所有正文地图 | **31 份** |

地图格式示例：
```markdown
## objc4-951.7/runtime/objc-cache.mm
- `cache_t` 结构: L142-L198
- `cache_fill_nolock()`: L1523
- `insert()` 实现: L1467-L1519
```

### 🤖 Agent 行为规范
通过 `AGENTS.md` / `CLAUDE.md` 强制 AI：
- ✅ 回答前必须读取对应 map 确认版本
- ✅ 引用源码时必须带文件路径和行号
- ✅ 发现版本不匹配时明确告知用户

### 🔒 版本管理脚本
- `sources.sh`：单一数据源，声明所有仓库的 Git URL 和锁定策略
- `bootstrap.sh`：一键下载并挂载地图（通过 symlink）
- `check-updates.sh`：只读检查更新（6 小时缓存）
- `update-sources.sh`：安全执行更新（三种策略：钉死标签/跟踪分支/最新标签）

---

## 🚀 快速开始

### Step 1: 克隆并初始化
```bash
git clone https://github.com/XiyouMobile3G-iOS/ios-source-learning.git
cd ios-source-learning
./bootstrap.sh  # 下载 ~2-3 GB，需 10+ 分钟
```

### Step 2: 向 AI 提问
现在可以问 AI 这样的问题：

> **"RunLoop 没有 source/timer 的时候为什么不会退出？"**

AI 会自动：
1. 读取 `maps/CF-1153.18-apple/AGENTS.md`
2. 定位到 `__CFRunLoopRun()` 的关键行号
3. 结合源码给出精确解释

> **"objc_msgSend 的缓存查找逻辑是怎样的？"**

AI 会：
1. 检查 `maps/new objc4/runtime/AGENTS.md`
2. 找到 `cache_fill_nolock()` 的实现位置
3. 解释缓存的插入和查找机制

### Step 3: 验证和探索
```bash
# 所有源码都下载到项目根目录（已加入 .gitignore）
cd 'new objc4/runtime'
# 直接查看 AI 引用的代码行
```

新增或修改地图后，先在 `maps/` 中完成编辑，再运行下面的命令重新挂载入口文件：

```bash
./bootstrap.sh --maps-only
```

---

## ⚙️ 工作原理

<details>
<summary>点击展开</summary>

### 地图结构
每个 map 文件包含：
- **文件清单**：该模块的关键源文件列表
- **符号索引**：重要函数、结构体、宏定义的行号
- **版本锁定**：明确标注对应的 Git tag/commit
- **目录结构**：便于快速定位文件位置

### AI 工作流
```mermaid
graph LR
    A[用户提问] --> B[AI 读取对应 map]
    B --> C[确认版本一致]
    C --> D[定位精确行号]
    D --> E[读取源码]
    E --> F[生成解释]
```

### 版本锁定策略
- **钉死标签**（第三方库）：`AFNetworking@4.0.1`，只报告更新不自动升级
- **跟踪分支**（Swift 源码等）：追踪 `sources.sh` 指定的分支，仅 fast-forward 合并
- **最新标签**（部分 Apple 库）：自动切换到最新 tag

</details>

---

<a id="version-coverage"></a>

## 📌 版本覆盖

`libdispatch` 目标对应上游 `swift-corelibs-libdispatch`，在下表中单列，避免与 Apple drop 混淆。

| 仓库 | 当前 ref | 更新策略 | 地图数量 |
|------|---------|---------|---------|
| **objc4-apple** | `objc4-951.7` | 钉死标签 | 7 |
| **CF-apple** | `main`（停在 `CF-1153.18`） | 跟踪分支 | 1 |
| **libdispatch-apple** | 版本号最高的 tag | `latest`，自动切换 | 1 |
| **swift-corelibs-libdispatch** | `main` | 跟踪分支 | 1 |
| **swift-corelibs-foundation** | `main` | 跟踪分支 | 1 |
| **swift-foundation** | `main` | 跟踪分支 | 1 |
| **gnustep-base** | `base-1_31_1` | 钉死标签 | 1 |
| **AFNetworking** | `4.0.1` | 钉死标签 | 4 |
| **JSONModel** | `1.8.0` | 钉死标签 | 5 |
| **YYModel** | `1.0.4` | 钉死标签 | 3 |
| **SDWebImage** | `5.21.7` | 钉死标签 | 6 |
| **合计** |  |  | **31** |

检查更新：
```bash
./check-updates.sh -v  # 检查所有仓库的更新状态（只读，6 小时缓存）
./update-sources.sh    # 执行安全更新
```

### 更新约定

先运行 `./check-updates.sh`，再决定是否执行更新。退出码是给 agent 与自动化判断用的：

| 退出码 | 输出开头 | 含义与下一步 |
|--------|---------|--------------|
| 0 | `UPTODATE` | 直接读源码，不要运行 `update-sources.sh` |
| 10 | `UPDATE` | 运行 `./update-sources.sh` 后再读源码 |
| 2 | `ERROR` | 检查失败；若网络权限允许则用相同参数重试一次，仍失败时须声明基于本地版本作答 |

检查同时发现更新与错误时，`ERROR` 优先（退出码 `2`）；输出仍会列出已发现的更新，
但不能假定未报出更新的其他源码已经完成远端核对。

`NOTICE` 表示有版本可人工处理，但**不改变退出码**：objc4、gnustep-base 与四份第三方库钉在 tag，
`update-sources.sh` 对它们只 fetch 并报告，绝不自动切换 ref，以免地图行号失效。

其余策略由 `sources.sh` 统一定义：`track` 目标仅以 `merge --ff-only` 追踪配置分支，
若本地当前分支与清单不符，`check-updates.sh` 会返回 `ERROR`，`update-sources.sh` 会跳过该目标；
`latest` 目标会切到版本号最高的 tag。不要手动用 `git fetch`、`git pull` 或 `git checkout` 绕过脚本。

---

## 🤝 贡献地图

欢迎提交新的 source map！请遵循以下规范：

### ✅ 地图应该包含
- 文件列表和目录结构
- 关键符号（函数、结构体、宏）+ 行号
- 版本锁定信息（Git tag/commit）

### ❌ 地图不应包含
- 源码解释和推导（留给 AI）
- 复制粘贴的源码片段
- 教程式的内容
- 超过 200 行的单个地图

### 提交流程
1. Fork 本仓库并创建分支。
2. 新地图必须先写在 `maps/` 对应位置，再运行 `./bootstrap.sh --maps-only` 挂载；直接在下载的源码目录新建文件会成为游离文件，其他人 clone 不到。
3. 地图正文一律写入 `AGENTS.md`，同目录 `CLAUDE.md` 只保留三行指针；仓库根目录例外，根 `CLAUDE.md` 必须是指向根 `AGENTS.md` 的符号链接，避免自动加载时丢失规范。
4. 新增上游源码时，在 `sources.sh` 添加版本与策略，并确认源码目录被 `.gitignore` 忽略；不要改三个脚本中重复的清单。
5. 源码升版时，同时修改 `sources.sh` 的 ref 并校对所有受影响地图的行号；钉死版本的仓库不能只升级源码不改地图。
6. 提交 PR，说明覆盖模块、版本与验证方式。

---

<a id="license"></a>

## 📄 许可证

- **地图文件和脚本**：本项目原创内容，MIT License
- **上游源码**：遵循各自原始许可证
  - Apple 源码：APSL (Apple Public Source License)
  - Swift 源码：Apache License 2.0
  - gnustep-base：LGPL-2.1+
  - 第三方库：MIT License (AFN, JSONModel, YYModel, SDWebImage)

**注意**：本仓库不包含源码本身（已加入 `.gitignore`），所有源码通过 `bootstrap.sh` 从上游仓库获取。

---

## 🔗 相关资源

- [AGENTS.md](AGENTS.md) - AI Agent 行为规范详细说明
- [CLAUDE.md](CLAUDE.md) - Claude 专用配置
- [maps/](maps/) - 所有源码地图索引

---

<div align="center">

**Made with ❤️ for AI-powered iOS learning**

[提交 Issue](https://github.com/XiyouMobile3G-iOS/ios-source-learning/issues) · [贡献地图](https://github.com/XiyouMobile3G-iOS/ios-source-learning/pulls)

</div>
