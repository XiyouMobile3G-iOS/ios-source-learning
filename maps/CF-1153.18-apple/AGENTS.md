# CoreFoundation CF-1153.18 —— 文件地图

macOS 10.13.6 的真实 drop，**研究 iOS/macOS RunLoop 行为以本目录为准**。
Apple 自此停止开源 CF，上游不会再更新。全部 `.c`/`.h` 平铺在根目录，无子目录分层。

规模：168 文件，86393 行 C。**不要整读任何一个大文件**，用下面的行号 + `Read` 的 `offset`/`limit`。

---

## RunLoop —— `CFRunLoop.c`（3955 行）

### 数据结构

| 结构 | 行号 |
|---|---|
| `struct __CFRunLoopMode` | `524` |
| `struct __CFRunLoop` | `637` |
| `struct __CFRunLoopSource` | `946` |
| `struct __CFRunLoopObserver` | `984` |
| `struct __CFRunLoopTimer` | `1052` |

### 循环三层

| 内容 | 行号 |
|---|---|
| `CFRunLoopRun` —— 外层 do-while，超时传 `1.0e10` | `2676` |
| `CFRunLoopRunSpecific` —— 空 mode 提前返回 | `2649`，判断在 `2654` |
| `__CFRunLoopRun` —— 循环本体 | `2331` |
| ↑ 出口判定 + `while (0 == retVal)` | `2618-2637` |
| `__CFRunLoopServiceMachPort` —— `mach_msg` 睡眠点 | `2201` |

### 保活判断（高频问题）

| 内容 | 行号 |
|---|---|
| **`__CFRunLoopModeIsEmpty`** | `831` |
| ↑ 主 RunLoop 永不为空的短路 | `838` |
| ↑ sources0 / sources1 / timers 计数 | `839` / `840` / `841` |
| ↑ blocks 链表检查（易漏） | `842-853` |

`838` 行的条件是 `CFSetContainsValue(rl->_commonModes, rlm->_name)`——主体是 RunLoop 的 commonModes 集合，被查的是 mode 名，别记反。

### 回调与增删

| 内容 | 行号 |
|---|---|
| `__CFRunLoopDoObservers` | `1668` |
| `__CFRunLoopDoSources0` | `1764` |
| `__CFRunLoopDoSource1` | `1829` |
| `CFRunLoopGetMain` / `GetCurrent` | `1482` / `1489` |
| `CFRunLoopWakeUp` / `CFRunLoopStop` | `2708` / `2729` |
| `CFRunLoopAddSource` / `AddTimer` | `2839` / `3129` |
| `CFRunLoopSourceCreate` / `ObserverCreate` | `3304` / `3496` |

RunLoop 配套：`CFMachPort.c`（source1 底层）、`CFSocket.c`（3477）、`CFMessagePort.c`、`CFStream.c`。

---

## 其余按主题分组

| 主题 | 主要文件（括号为行数） |
|---|---|
| 运行时基础 | `CFRuntime.c`(1612，CF 对象模型/引用计数)、`CFBase.c`、`CFInternal.h`(内部宏与 TSD)、`CFPlatform.c` |
| 集合 | `CFArray.c`、`CFDictionary.c`、`CFSet.c`、`CFBag.c`、`CFBasicHash.c`(1770，哈希核心)、`CFBinaryHeap.c`、`CFStorage.c`(1479，分块存储)、`CFTree.c` |
| 字符串 | `CFString.c`(6570，最大)、`CFStringEncoding*.c`、`CFUniChar*.c`、`CFUnicodeDecomposition.c`、`CFBurstTrie.c`(2076) |
| 属性列表 | `CFPropertyList.c`(3146)、`CFBinaryPList.c`、`CFOldStylePList.c`、`CFXML*.c` |
| Bundle / 插件 | `CFBundle*.c`(8 个)、`CFPlugIn*.c` |
| 时间 / 本地化 | `CFDate.c`、`CFCalendar.c`、`CFTimeZone.c`、`CFLocale*.c`、`CFDateFormatter.c`(2001)、`CFNumberFormatter.c` |
| URL / 流 / IO | `CFURL.c`(4966)、`CFURLAccess.c`、`CFStream.c`(2062)、`CFConcreteStreams.c`、`CFFileUtilities.c` |
| 偏好设置 | `CFPreferences.c`、`CFApplicationPreferences.c`、`CFXMLPreferencesDomain.c` |

## 私有头文件

- `CFInternal.h` —— 内部宏、TSD key、锁
- `CFPriv.h` —— SPI
- `ForFoundationOnly.h` —— 只给 Foundation 用的接口，**看 NSObject/NSString 与 CF 的桥接从这里入手**

## 构建

`Makefile` / `MakefileLinux`（CFLite），说明见 `README_CFLITE`。
**这份是精简包（只有 168 个文件），直接 make 大概率失败，定位为只读研究。**

## 与 swift-corelibs 版的差异

`../swift-corelibs-foundation/Sources/CoreFoundation/CFRunLoop.c` 是 4772 行，多出 `rlm->_queue` / `_dispatch_runloop_root_queue_perform_4CF` 分支，且走 epoll 等跨平台后端。**行号完全对不上，别混用。**
