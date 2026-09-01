# iOS Source Learning

> 🤖 **给 AI Agent 用的 iOS 源码导航层**
> 62 个手写地图 + 版本锁定 + 行为规范，让 AI 精确回答 iOS 底层问题

<div align="center">

[![Maps](https://img.shields.io/badge/Source_Maps-62-blue.svg)](maps/)
[![Pinned Versions](https://img.shields.io/badge/Versions-Pinned-green.svg)](#版本覆盖)
[![License](https://img.shields.io/badge/License-Mixed-orange.svg)](#许可证)

</div>

---

## 💡 为什么需要这个项目

### 痛点
- ❌ AI 回答 iOS 底层问题时容易**幻觉**（编造 API、混淆版本）
- ❌ 源码版本不一致导致**行号对不上**、讨论无法复现
- ❌ 缺少导航索引，AI 需要**遍历大量文件**才能定位关键逻辑

### 解决方案
- ✅ **强制版本验证**：通过 `AGENTS.md` 规范，AI 必须先检查版本再回答
- ✅ **精确行号导航**：62 个手写地图预先标注关键符号和行号
- ✅ **一键环境复现**：`bootstrap.sh` 自动下载并锁定所有源码版本

---

## 📦 三大核心资产

### 📍 62 个源码地图
手写的导航索引，覆盖：

| 类别 | 覆盖范围 | 地图数量 |
|------|---------|---------|
| **Apple 底层** | objc4 (runtime, isa, msgSend, cache_t, ARC)<br>CoreFoundation (RunLoop, CFString)<br>libdispatch (GCD, Queue, Semaphore)<br>swift-foundation (Swift 重写的 Foundation) | ~40 个 |
| **参考实现** | gnustep-base (NSNotificationCenter, KVO) | ~8 个 |
| **三方库** | AFNetworking 4.x, JSONModel, YYModel, SDWebImage 5.x | ~14 个 |

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
1. 读取 `maps/CF-1153.18-apple/CFRunLoop.md`
2. 定位到 `__CFRunLoopRun()` 的关键行号
3. 结合源码给出精确解释

> **"objc_msgSend 的缓存查找逻辑是怎样的？"**

AI 会：
1. 检查 `maps/objc4-951.7-apple/objc-cache.md`
2. 找到 `cache_fill_nolock()` 的实现位置
3. 解释缓存的插入和查找机制

### Step 3: 验证和探索
```bash
# 所有源码都下载到项目根目录（已加入 .gitignore）
cd objc4-951.7-apple/runtime
# 直接查看 AI 引用的代码行
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
- **跟踪分支**（Swift 源码）：`release/6.0` 分支，仅 fast-forward 合并
- **最新标签**（部分 Apple 库）：自动切换到最新 tag

</details>

---

## 📌 版本覆盖

| 仓库 | 锁定版本 | 更新策略 | 地图数量 |
|------|---------|---------|---------|
| **objc4-apple** | `objc4-951.7` | 钉死标签 | 6 |
| **CF-apple** | `CF-1153.18` | 钉死标签 | 8 |
| **libdispatch-apple** | 最新 tag | 自动跟踪 | 6 |
| **swift-corelibs-foundation** | `release/6.0` 分支 | 跟踪分支 | 4 |
| **swift-foundation** | `release/6.0` 分支 | 跟踪分支 | 4 |
| **gnustep-base** | `base-1_31_0` | 钉死标签 | 8 |
| **AFNetworking** | `4.0.1` | 钉死标签 | 4 |
| **JSONModel** | `1.8.0` | 钉死标签 | 3 |
| **YYModel** | `1.0.4` | 钉死标签 | 3 |
| **SDWebImage** | `5.21.7` | 钉死标签 | 4 |

检查更新：
```bash
./check-updates.sh -v  # 检查所有仓库的更新状态（只读，6 小时缓存）
./update-sources.sh    # 执行安全更新
```

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
1. Fork 本仓库
2. 在 `maps/` 下创建新地图
3. 在 `sources.sh` 中声明版本锁定
4. 提交 PR 并说明覆盖的模块

---

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
