# CLAUDE.md — objcdt/ 模块记忆

命令行调试工具，用于 dump 活进程里的 Objective-C runtime 状态。上层见 [根 CLAUDE.md](../CLAUDE.md)。等价指针文件 `AGENTS.md`。

## ⚠️ 本 drop 中是空壳

`objcdt.mm` 的 `main()`（第 34 行）**直接 `return EX_UNAVAILABLE;`**，整个文件仅 37 行。真正的实现没有随开源 drop 一起发布。所以：

- 构建出来的 `objcdt` 可执行文件跑起来什么都不做
- 不要基于它调试 runtime，也不要花时间"修复"它——这不是 bug，是 Apple 有意剔除的部分
- `objcdt.1`（man page）描述的是**内部完整版**的行为，与本仓库代码不符

## 目录

| 文件 | 行数 | 说明 |
|---|---|---|
| `objcdt.mm` | 37 | 入口，已被剔除为 stub |
| `json.h` | 82 | JSON 输出辅助（`objcdt` 原本以 JSON 格式 dump） |
| `json.mm` | 234 | 上述实现，是本目录唯一有实质内容的代码 |
| `objcdt.1` | — | man page，由 xcodeproj 的 "Install Manpages" 脚本阶段安装 |
| `objcdt-entitlements.plist` | — | 需要读取其他进程内存的 entitlements |

它 `#include` 了 `runtime/objc-private.h`、`objc-ptrauth.h`、`NSObject-private.h`——即工具与 runtime 内部结构强耦合，若要自己补实现，会随 runtime 数据结构变动而失效。

## 替代方案

想在本仓库里观察 runtime 行为，用这两条路而不是 objcdt：

1. `runtime/objc-env.h` 里的 `OBJC_PRINT_*` / `OBJC_DEBUG_*` 环境变量（`OBJC_PRINT_CLASS_SETUP`、`OBJC_PRINT_LOAD_METHODS`、`OBJC_PRINT_CACHE_SETUP` 等）
2. `runtime/objc-gdb.h` 暴露给调试器的符号与结构契约，配合 lldb 直接读

（`ObjectiveC.xcscheme` 是本仓库唯一的共享 scheme，跑的是 Swift overlay 测试，与 objcdt 无关。）
