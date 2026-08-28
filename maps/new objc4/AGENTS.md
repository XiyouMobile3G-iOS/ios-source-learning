# objc4-951.7 —— 仓库地图与模块索引

objc4 源码树的导航索引，供 agent 定位文件与符号，不是学习笔记。

> 同目录的 `CLAUDE.md` 只是指向本文件的指针，内容等价，**不要重复读取**。各模块目录下同样成对存在 `AGENTS.md`（正文）/ `CLAUDE.md`（指针）。

## 模块地图索引（渐进式披露）

本文件只给全局背景与构建/测试命令。**动手改某个模块前，先读该模块的 `AGENTS.md`**——里面是文件级目录表和关键符号，用于快速定位源码，避免全仓库扫描。

| 模块 | 地图文件 | 覆盖内容 |
|---|---|---|
| runtime 主体 | [`runtime/AGENTS.md`](./runtime/AGENTS.md) | 「按任务定位」总表、三层头文件划分、`objc-runtime-new.h` 数据结构地图、类实现化/category/ivar 的主流程、NSObject.mm 分区 |
| 消息发送汇编 | [`runtime/Messengers.subproj/AGENTS.md`](./runtime/Messengers.subproj/AGENTS.md) | 各架构 `.s` 文件、`objc_msgSend` 系列入口点行号、与 C 侧结构布局的耦合点 |
| 线程与锁 | [`runtime/Threading/AGENTS.md`](./runtime/Threading/AGENTS.md) | 后端选择与 mixin 组装、`tls_key` 分配表、全局锁声明位置与加锁顺序、fork 安全 |
| C 侧测试套件 | [`test/AGENTS.md`](./test/AGENTS.md) | `test.pl` 用法、`TEST_*` 指令全表、`test.h`/`testroot.i` 宏、测试命名规律 |
| Swift overlay | [`ObjectiveC/AGENTS.md`](./ObjectiveC/AGENTS.md) | `ObjectiveC.swift` 内容地图、xcconfig 里绕 bug 的非显然设置、XCTest 跑法 |
| 调试工具 | [`objcdt/AGENTS.md`](./objcdt/AGENTS.md) | **本 drop 中是空壳**，勿浪费时间；替代调试手段 |

## 仓库性质

Apple 开源的 Objective-C runtime（objc4）源码，产物是 `libobjc.A.dylib`。当前分支 `objc4-951.7`，每个 commit 对应一次 Apple 源码 drop（`objc4-928.2` → `940.4` → `950` → `951.1` → `951.7`），可用 `git diff HEAD~1 HEAD` 直接查看版本间的 runtime 变更——这是研究 runtime 演进的主要手段。

**重要**：这是 Apple 内部工程，构建脚本依赖 `macosx.internal` SDK（见 `markgc` 脚本阶段）和 `/AppleInternal` 路径。在公开 Xcode 上直接 build `objc` target 会失败，通常需要补齐私有头文件并裁剪脚本阶段。修改代码前先确认当前是"阅读/研究"还是"实际构建"场景。

## 构建与测试

```bash
# 构建 dylib（需要 internal SDK，见上）
xcodebuild -project objc.xcodeproj -target objc -sdk macosx

# 各 target 用途：
#   objc                 → libobjc.A.dylib 本体
#   objc-trampolines     → libobjc-trampolines.dylib（block trampolines）
#   objcdt               → 运行时调试/dump 工具（objcdt.1 是 man page）
#   objc-env             → 从 runtime/objc-env.h 生成环境变量文档
#   ObjectiveC           → Swift overlay（ObjectiveC.swift）
#   ObjectiveCTests      → Swift overlay 的 XCTest（ObjectiveC.xctestplan 只覆盖这个）
#   objc4_tests          → 打包 test/ 下的 BATS 测试到 DSTROOT
#   objc-simulator / objc-vfs-overlay → 模拟器与 VFS overlay 聚合 target
```

主测试套件是 `test/` 下 260+ 个独立可执行测试，由 Perl 驱动，**不是** XCTest：

```bash
cd test
perl test.pl                      # 跑全部（对着系统已安装的 libobjc）
perl test.pl msgSend              # 跑单个测试（名字 = 文件名去掉扩展名）
perl test.pl -h                   # 完整参数说明

# 对自己构建的 root 做测试
perl test.pl ROOT=/tmp/objc4.roots ARCH=arm64 MEM=mrc,arc LANGUAGE=c,c++,objective-c,objective-c++
perl test.pl VERBOSE=2 badCache   # VERBOSE=2 打印完整测试输出，调试首选
perl test.pl BUILD=1 RUN=0 ...    # 只编译不运行
```

`test.pl` 会在 ARCH × OS × LANGUAGE × MEM × GUARDMALLOC 维度上做笛卡尔积多路复用，一个测试文件会被反复编译成多种配置。

写测试的完整规则（`TEST_*` 指令表、`test.h`/`testroot.i` 宏、必须打印 `OK: <name>`）见 [`test/AGENTS.md`](./test/AGENTS.md)。

## 全局地图

只记"哪一层做什么"，具体文件与符号见对应模块地图：

- `runtime/` —— libobjc 全部实现。核心是 `objc-runtime-new.mm/.h`（类实现化、category、非脆弱 ivar、全部数据结构）；引用计数快路径在 `objc-object.h` + `isa.h`，**不在** `NSObject.mm`。→ [`runtime/AGENTS.md`](./runtime/AGENTS.md)
- `runtime/Messengers.subproj/` —— `objc_msgSend` 各架构汇编，与 `cache_t`/`objc_class` 的内存布局强耦合。→ [模块地图](./runtime/Messengers.subproj/AGENTS.md)
- `runtime/Threading/` —— 锁/TLS 抽象层，后端由 `objc-config.h` 的 `OBJC_THREADING_PACKAGE` 选择。→ [模块地图](./runtime/Threading/AGENTS.md)
- `test/` —— C 侧主测试套件（Perl 驱动）。→ [模块地图](./test/AGENTS.md)
- `ObjectiveC/` + `ObjectiveCTests/` —— Swift overlay 与其 XCTest。→ [模块地图](./ObjectiveC/AGENTS.md)
- `objcdt/` —— 调试工具，本 drop 中是空壳。→ [模块地图](./objcdt/AGENTS.md)

### 三处全局配置入口

- `runtime/objc-config.h` —— 编译期特性开关（`SUPPORT_NONPOINTER_ISA`、`SUPPORT_PACKED_ISA`/`SUPPORT_INDEXED_ISA`、`SUPPORT_TAGGED_POINTERS`、`SUPPORT_PREOPT`、`SUPPORT_STRET`、`SUPPORT_FIXUP` 等）。判断"某平台上这段代码是否生效"先查这里。
- `runtime/objc-env.h` —— X-macro 定义**全部** `OBJC_PRINT_*` / `OBJC_DEBUG_*` 环境变量。加一行 `OPTION(...)` 即可新增调试开关；`objc-env` target 生成文档，可能需同步 `test/defines.expected`。
- `objc4.plist` —— 运行期 feature flags（`preoptimizedCaches`、`classRxSigning` 等），由脚本阶段安装。

头文件的三层可见性（公开 / SPI / 内部）以及 `objc.xcconfig`、`runtime/Module*/` modulemap+apinotes 的配合规则，见 [`runtime/AGENTS.md`](./runtime/AGENTS.md) 的「分层」一节——新增 API 时这几处要一起改。

## 约定

- 实现文件是 `.mm`（Objective-C++），但 runtime 内部**不使用** ObjC 对象和 ARC，用 C++ 写；只在必要处用 ObjC。
- 内部代码用 `ASSERT()`（`objc-private.h`），不用 `assert()`。
- 缩进 4 空格（`.editorconfig`），与用户全局 OC 规范的 2 空格不同——**此仓库跟随 Apple 原有风格**，改动要与周围代码一致。
- 尽量保持与上游 Apple 源码的最小 diff，便于下次 drop 合并。
