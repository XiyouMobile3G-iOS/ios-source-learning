# Messengers.subproj/ —— 模块地图

`objc_msgSend` 及其变体的各架构汇编实现。上层见 [runtime/AGENTS.md](../AGENTS.md)。等价指针文件 `CLAUDE.md`。

## 目录

| 文件 | 行数 | 适用平台 |
|---|---|---|
| `objc-msg-arm64.s` | 868 | arm64 / arm64e（真机，含 ptrauth） |
| `objc-msg-arm.s` | 907 | armv7（32 位，遗留） |
| `objc-msg-x86_64.s` | 1382 | Intel macOS |
| `objc-msg-i386.s` | 1087 | 32 位 Intel（遗留） |
| `objc-msg-simulator-x86_64.s` | 1270 | Intel 模拟器 |
| `objc-msg-simulator-i386.s` | 993 | 32 位模拟器（遗留） |
| `objc-msg-win32.m` | 525 | Windows 端口，C 实现，不参与 Xcode 构建 |

改动**必须同时改所有在用架构**（至少 arm64 + x86_64 + 两个 simulator），否则会出现只在某架构崩溃的问题。

## 入口点（以 arm64 为例，行号对应 951.7）

| 符号 | 行 | 说明 |
|---|---|---|
| `_objc_msgSend` | — | 主入口，缓存命中走 `CacheLookup NORMAL`，未命中跳 `__objc_msgSend_uncached` |
| `_objc_msgLookup` | 622 | 只查 IMP 不调用，供 Swift/调试用 |
| `__objc_msgNil` / `__objc_returnNil` | 652 / 664 | nil receiver 的返回值清零路径 |
| `_objc_msgSendSuper` | 673 | `super` 调用（旧形式） |
| `_objc_msgSendSuper2` | 683 | `super` 调用（编译器实际发射的形式，传的是类本身而非父类） |
| `_objc_msgLookupSuper2` | 702 | 同上的 lookup 版 |
| `__objc_msgSend_uncached` | 737 | 缓存未命中 → 调 C 侧 `lookUpImpOrForward` |
| `__objc_msgLookup_uncached` | 749 | 同上的 lookup 版 |
| `_cache_getImp` | 761 | 只查缓存，不触发 resolve/forward |
| `__objc_msgForward_impcache` / `__objc_msgForward` | 788 / 796 | 消息转发跳板 |
| `_objc_msgSend_noarg` | 806 | 无参数快路径 |
| `_objc_msgSend_debug` / `_objc_msgSendSuper2_debug` | 810 / 814 | 调试变体 |
| `_method_invoke` | 819 | `method_invoke()` 的汇编实现 |

`ENTRY` / `STATIC_ENTRY` / `GLOBAL_ENTRY` 是文件内定义的宏；查所有入口用
`grep -nE '^\s*(ENTRY|STATIC_ENTRY|GLOBAL_ENTRY)' objc-msg-arm64.s`。

## 与 C 侧的耦合点

这些汇编硬编码了 C 结构体的偏移与位掩码，任何一处改动都要在这里同步核对：

- `cache_t` / `bucket_t` 布局与 `cache_hash` 算法 → `runtime/objc-runtime-new.h`、`runtime/objc-cache.mm`
- `objc_class` 中 `isa`/`superclass`/`cache`/`bits` 的顺序 → `runtime/objc-runtime-new.h` 的 `objc_class`
- isa 的 `ISA_MASK` / tagged pointer 位 → `runtime/isa.h`、`runtime/objc-config.h`
- 未命中回调的 C 函数签名 → `lookUpImpOrForward`（`runtime/objc-runtime-new.mm`）
- arm64e 的指针签名 discriminator → `runtime/objc-ptrauth.h`

`runtime/arm64-asm.h` 提供 arm64/arm64_32 与 ptrauth 的汇编宏；`runtime/retain-release-helpers-arm64.s` 是相关的 retain/release 汇编辅助。

## 测试

`test/msgSend.m` 会反汇编 `objc_msgSend` 做校验（见其顶部 `TEST_BUILD` 用 `asm-placeholder.s`）。改汇编后至少跑：

```bash
cd test && perl test.pl VERBOSE=2 msgSend
```

相关测试还有 `test/msgSend-*`、`test/badCache.m`、`test/cacheflush*`、`test/forward*`。
