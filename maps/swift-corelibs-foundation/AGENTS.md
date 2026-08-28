# swift-corelibs-foundation —— 用途与地图

`apple/swift-corelibs-foundation`，分支 `main`，blobless clone。
**记录时 commit `761b621d`，snapshot `swift-DEVELOPMENT-SNAPSHOT-2026-08-21-a`；
这份追 main，引用务必带 commit。**

## 先看这条

**研究 iOS/macOS 的 CoreFoundation 行为用 [`../CF-1153.18-apple/`](../CF-1153.18-apple/AGENTS.md)，不是本目录。**
本目录含大量 Linux/Windows 适配，与真实二进制有出入。它的价值是：

1. **查新**——Apple 的 CF 停更在 10.13.6，10.13 之后 CF 怎么演进只能看这里；
2. **对照**——同一函数两版对比，能看出哪些是平台适配、哪些是真实现；
3. **Foundation 的 Swift 实现**——`NSString`/`Operation`/`Port` 等的可读源码。

---

## 目录结构

| 路径 | 内容 |
|---|---|
| `Sources/CoreFoundation/` | 96 文件，97256 行 C。C 版 CF |
| `Sources/CoreFoundation/include/` | CF 头文件（Apple 版是平铺在根目录的） |
| `Sources/Foundation/` | 55038 行 Swift，Foundation 实现 |
| `Sources/FoundationNetworking/` | URLSession 等 |
| `Sources/FoundationXML/` | XML |
| `Sources/_CFURLSessionInterface/`、`_CFXMLInterface/` | C 桥接层 |
| `Sources/Testing/`、`XCTest/` | 测试基础设施 |
| `Tests/` | **查某 API 预期行为的好去处** |

---

## `Sources/CoreFoundation/` 大文件

| 文件 | 行数 | 对应 Apple 版 |
|---|---|---|
| `CFString.c` | 7946 | 6570 |
| `CFURL.c` | 5494 | 4966 |
| **`CFRunLoop.c`** | **4772** | **3955** |
| `CFPropertyList.c` | 3288 | 3146 |
| `CFCharacterSet.c` | 3203 | 2923 |
| `CFCalendar.c` | 3012 | 1359 |
| `CFSocket.c` | 2714 | 3477 |

**行号一律不通用。** `CFRunLoop.c` 尤其：本版 `__CFRunLoopModeIsEmpty` 多出 `rlm->_queue` + `_dispatch_runloop_root_queue_perform_4CF` 分支，Apple 版没有。

## 10.13 之后 CF 的增量

本目录有、`CF-1153.18-apple/` 没有的文件，就是演进方向：

`CFAttributedString.c`、`CFDateComponents.c`、`CFDateInterval.c`、`CFDateIntervalFormatter.c`、`CFCalendar_Enumerate.c`、`CFBundle_Executable.c`、`CFBundle_DebugStrings.c`、`CFBundle_SplitFileName.c`、`CFBundle_Tables.c`、`CFBundle_Main.c`、`CFBundle_ResourceFork.c`

## `Sources/Foundation/` 大文件

| 文件 | 行数 |
|---|---|
| `Unit.swift` | 2620 |
| `NSStringAPI.swift` | 1780 |
| `NSString.swift` | 1745 |
| `NSURL.swift` | 1637 |
| `Operation.swift` | 1444（NSOperation/Queue 的可读实现） |
| `NumberFormatter.swift` | 1426 |
| `NSData.swift` | 1254 |
| `Process.swift` | 1232 |
| `Port.swift` | 1148（NSMachPort / RunLoop 保活相关） |

## 版本追踪

有完整 git 历史，可 `git log --oneline -- Sources/CoreFoundation/CFRunLoop.c` 看单文件演进。
blobless clone，checkout 历史版本需联网；要频繁切版本先转完整 clone（方法见父目录 `../AGENTS.md`）。
