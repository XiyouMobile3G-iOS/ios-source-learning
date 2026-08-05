# CLAUDE.md — ObjectiveC/ 模块记忆（Swift overlay）

`libswiftObjectiveC.dylib`：Swift 侧的 ObjectiveC 模块 overlay。上层见 [根 CLAUDE.md](../CLAUDE.md)。等价指针文件 `AGENTS.md`。

测试在同级的 `ObjectiveCTests/`（本文件一并覆盖），是本仓库**唯一的 XCTest**，由 `ObjectiveC.xctestplan` + `ObjectiveC.xcscheme` 驱动；C 侧测试是完全不同的一套，见 [test/CLAUDE.md](../test/CLAUDE.md)。

## 目录

| 文件 | 行数 | 说明 |
|---|---|---|
| `ObjectiveC.swift` | 381 | overlay 全部源码 |
| `ObjectiveC.xcconfig` | — | 构建配置，坑最多的地方，见下 |
| `ObjectiveCRPathInstallName.h/.c` | — | rpath 安装名辅助，通过 `TAPI_EXTRA_PROJECT_HEADERS` 参与 TAPI 校验 |
| `../ObjectiveCTests/ObjectiveC.swift` | 200 | 主测试 |
| `../ObjectiveCTests/Creatures.swift` | 114 | 类枚举测试用的类层级夹具 |
| `../ObjectiveCTests/StdlibUnittest-checkEquatable.swift` | 112 | 从 Swift stdlib unittest 抄来的 Equatable 校验 |
| `../ObjectiveCTests/StdlibUnittest-checkHashable.swift` | 166 | 同上，Hashable |
| `../ObjectiveC-swiftoverlay-Test-Dylib/` | — | `test_08_Dylib` / `test_09_FromDylib` 用的被测 dylib |

## ObjectiveC.swift 内容地图

| 行 | 内容 |
|---|---|
| 27 | `ObjCBool` —— BOOL 桥接。注意 x86_64 macOS / 32 位 iOS 上底层是 `Int8`，其余平台是 `Bool`，有 `#if` 分支 |
| 88 / 94 | `_convertBoolToObjCBool` / `_convertObjCBoolToBool` —— 标记为 `COMPILER_INTRINSIC`，**编译器按名字查找**，不能改名 |
| 107 | `Selector` —— `ExpressibleByStringLiteral`、`@unchecked Sendable`；`Equatable`/`Hashable`/`CustomStringConvertible`/`CustomReflectable` 一族扩展在 124–158 |
| 139 | `String` 的扩展（从 Selector 构造） |
| 160 | `NSZone` |
| 176 / 180 | `_autoreleasePoolPush` / `_autoreleasePoolPop` —— 直连 runtime |
| 185 | `autoreleasepool<E, Result: ~Copyable>` —— 当前 ABI，支持 typed throws 与非 Copyable 返回值 |
| 200 | `__autoreleasepool_old_abi` —— 旧 ABI 兼容入口，**不能删**，有历史二进制依赖 |
| 211 / 215 | `YES` / `NO` |
| 228 / 278 | `NSObject` 的 `Equatable`/`Hashable`、`CVarArg` 一致性 |
| 293–373 | 类枚举 API：`ObjCEnumerationImage`、`ObjCClassList: Sequence`、`objc_enumerateClasses(fromImage:)` |

overlay 通过 `@_exported import ObjectiveC` 转发公开模块，通过 `@_implementationOnly import ObjectiveC_Private.objc_internal` 使用 SPI——即 overlay 能看到 `runtime/objc-internal.h`，这条通路由 `runtime/ModulePrivate/ObjectiveC_Private.modulemap` 定义。给 overlay 加新的 runtime 依赖时要先确认该 modulemap 已导出对应头。

## xcconfig 里的非显然约束

改这个文件前先读完注释，几个设置是绕 bug 用的，不能"顺手清理"：

- `SWIFT_ENABLE_EXPLICIT_MODULES = NO` —— 绕 rdar://144797648（explicit modules 会预构建 Dispatch overlay，而它反过来依赖本 overlay）
- `GCC_PREPROCESSOR_DEFINITIONS` 里的 `OS_OBJECT_HAVE_OBJC_SUPPORT=0` —— 打断 `ObjectiveC → MachO_Private → DispatchPrivate → Dispatch → os_object → ObjectiveC` 的模块循环
- `SWIFT_ENABLE_INCREMENTAL_COMPILATION = NO` —— 与 `-autolink-force-load` 冲突
- `-ivfsoverlay $(CONFIGURATION_TEMP_DIR)/objc-overlay.yaml` —— 由根目录 `objc-vfs-overlay/write-vfs-overlay.sh`（`objc-vfs-overlay` target）生成，让 overlay 编译时看到本仓库的头而不是 SDK 里的
- `INSTALL_PATH = $(SYSTEM_PREFIX)/usr/lib/swift`、`EXECUTABLE_PREFIX = libswift`、`BUILD_LIBRARY_FOR_DISTRIBUTION = YES`、`TAPI_VERIFY_MODE = Pedantic` —— 这是随 OS 发布的 ABI 稳定库，任何公开 API 改动都会被 TAPI 拦截

## 跑测试

```bash
xcodebuild test -project objc.xcodeproj -scheme ObjectiveC -testPlan ObjectiveC
```

测试类：`ObjectiveCTests`（`test_Hashable`）、`EnumerationTests`（`test_01`…`test_09`，覆盖类枚举的名字前缀、多条件、直接/扩展一致性、子类、提前退出、动态类、跨 dylib），以及 `testAutoreleasepool` 系列（含 noncopyable、throws、typed throws、old ABI 四个变体）。
