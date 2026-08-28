# swift-foundation —— 文件地图

Apple 的 **Foundation 核心实现**，Swift 重写版。`swift-corelibs-foundation` 现在只是外壳，
真正的实现体在这里；两个仓库**必须成对读**。

版本：分支 `main`（记录时 commit `56a12567`，2026-08-28）。
**这份追 main，行号会随更新漂移**——引用时务必带 commit，发现对不上就重新 `grep -n`。
规模：`Sources/` 共 138428 行 Swift。**不要整读任何一个大文件**。

## 与 swift-corelibs-foundation 的分工（先看懂这个再往下）

```
swift-corelibs-foundation/Sources/Foundation/     ← ObjC 兼容外壳，@objc API、NSXxx 类
        ↓ 依赖（Package.swift:166 引 apple/swift-foundation）
swift-foundation/Sources/FoundationEssentials/    ← 实现体，纯 Swift
swift-foundation/Sources/FoundationInternationalization/
```

跨仓库的接缝用 `@_spi(SwiftCorelibsFoundation)` 标记。**认准这个标记就能找到所有接缝。**

最典型的一条，也是本工作区引入这份源码的起因：

| 位置 | 内容 |
|---|---|
| `../swift-corelibs-foundation/Sources/Foundation/NSNotification.swift:93` | `NotificationCenter.post(_:)`，函数体只有一行 |
| ↑ 调用 `_post(notification.name.rawValue, subject:message:)` | `:94` |
| **落点** `Sources/FoundationEssentials/NotificationCenter/NotificationCenter.swift:118` | `_post` 的真身 |

在 corelibs 里 `grep "class NotificationCenter"` 零命中——**类本体只在这里**。

---

## 通知中心 —— `Sources/FoundationEssentials/NotificationCenter/`（6 文件 1154 行）

### `NotificationCenter.swift`（179 行，核心）

| 内容 | 行号 |
|---|---|
| `private struct AutoDictionary` —— 观察者容器，`UInt64` 自增键 + 空位回收 | `28` |
| ↑ `insert` / `remove` / `count` / `values` | `34` / `56` / `63` / `67` |
| `private let _defaultCenter`（全局单例） | `72` |
| `private struct MessageBox` —— 类型擦除的载荷盒 | `74` |
| **`open class NotificationCenter`** | `79` |
| ↑ **`registrar`** —— 全部状态就这一个字段 | `80` |
| ↑ `_actorQueueManager` | `81` |
| `open class var default` | `87` |
| **`_addObserver`** | `92` |
| **`_removeObserver`**（含空桶级联回收 `109-114`） | `105` |
| **`_post`** | `118` |
| `_NotificationObserverToken`（name + objectId + UInt64） | `172` |

`registrar` 的类型（`80`）就是整个数据模型，值得逐层看：

```swift
Mutex<[String?               /* Notification name，nil = 通配 */
      : [ObjectIdentifier?   /* object，nil = 通配 */
        : AutoDictionary<@Sendable (MessageBox) -> Void>]]>
```

**两级字典 + 一把 `Mutex`**，通配用 `nil` 键表示。跟 GNUstep 的三张独立表
（`../gnustep-base/Source/NSNotificationCenter.m:244` 的 `wildcard`/`nameless`/`named`）
是同一个问题的两种解法，**对照读收益很高**。

`_post`（`118`）的四次查表，顺序在 `126-137`：

| # | 查什么 | 行号 |
|---|---|---|
| ① | name + object 都精确匹配 | `127` |
| ② | name 通配（`nil`）+ object 精确 | `130` |
| ③ | name 通配 + object 通配（**仅 `subject != nil` 时**，判断在 `132`） | `134` |
| ④ | name 精确 + object 通配（同上条件） | `137` |

`119-120` 有一条 Apple 自己写的 TODO：**Darwin 上 observer 是按添加顺序调用的，
通配与非通配混在一起；这份实现做不到**。回答「通知回调顺序」类问题时必须提这一条。

投递本身在锁外：`141` 出锁，`143-144` 装盒后 `observers.forEach`。与 GNUstep 的
「持锁收集、解锁投递」是同一套思路。

### 类型化消息 API（Swift 6.2 新增，与上面那套字符串 API 并存）

| 文件 | 行数 | 内容 |
|---|---|---|
| `NotificationCenterMessage.swift` | 146 | `MessageIdentifier` `40`、`BaseMessageIdentifier` `47`、`ObservationToken` `65`、`removeObserver(_:)` `111` |
| `MainActorMessage.swift` | 266 | `protocol MainActorMessage` `99`；`addObserver` 三个重载 `153`/`169`/`183`；`post` `196`/`206`；私有 `_post` `250` |
| `AsyncMessage.swift` | 261 | `protocol AsyncMessage` `104`；`makeMessage`/`makeNotification` 桥接点 `117`/`125`，默认实现 `133`/`134`；`addObserver` `157`/`173`/`187`；`post` `199`/`206` |
| `AsyncMessage+AsyncSequence.swift` | 201 | `messages(of:)` 三个重载 `34`/`48`/`62`；迭代器 `90`，`next()` `184` |
| `ActorQueueManager.swift` | 101 | `_NotificationCenterActorQueueManager` `24`，`enqueue` `90` |

`AsyncMessage.swift:117` / `:125` 的 `makeMessage` / `makeNotification` 是
**新旧两套 API 互通的唯一桥**：老的字符串通知能被类型化 observer 收到，就靠这两个。

配套：`Sources/FoundationEssentials/Locale/Locale_Notifications.swift`。

---

## 其余按主题分组

`Sources/FoundationEssentials/` 下 18 个子目录，只列会用到的：

| 主题 | 目录 / 主要文件（行数） |
|---|---|
| 日历 / 日期 | `Calendar/`：`Calendar_Gregorian.swift`(3248)、`Calendar_Enumerate.swift`(2550)、`Calendar.swift`(1862)、`Calendar_Hebrew.swift`(1799) |
| URL | `URL/`：`URL.swift`(2094)、`URL_Impl.swift`(1598)、`URLParser.swift`(1478)、`URLComponents.swift`(1445) |
| JSON | `JSON/`：`JSONDecoder.swift`(1944)、`JSONEncoder.swift`(1588)、`JSONScanner.swift`(1397) |
| Data | `Data/`：`Data+Base64.swift`(1443) |
| plist | `PropertyList/`：`XMLPlistScanner.swift`(1509) |
| 其余 | `String/`、`AttributedString/`、`Predicate/`、`FileManager/`、`ProcessInfo/`、`ProgressManager/`、`Decimal/`、`Error/`、`Formatting/`、`Locale/`、`TimeZone/` |

其他 target：`FoundationInternationalization/`（ICU 相关）、`FoundationMacros/`（`#Predicate` 等宏）、
`_FoundationCShims/`（C 垫片）。

---

## 选型：这份 vs corelibs vs GNUstep vs CF

| 想搞清楚 | 去哪 |
|---|---|
| `NotificationCenter` 现在**实际**怎么存、怎么分发 | **本仓库** `Sources/FoundationEssentials/NotificationCenter/NotificationCenter.swift` |
| `NSNotification` / `NotificationQueue` 的 ObjC 兼容面 | `../swift-corelibs-foundation/Sources/Foundation/` |
| ObjC 时代 `NSNotificationCenter` 的经典实现思路 | `../gnustep-base/Source/NSNotificationCenter.m`（**非 Apple 代码**） |
| RunLoop / CF 对象模型 | `../CF-1153.18-apple/`（权威），本仓库没有 |

**注意**：本仓库是 Foundation 在 **Swift/跨平台**上的当前形态，不等于 iOS 上那个
ObjC 二进制的行为——`_post` 里 `119-120` 的 TODO 就是明写的差异。回答「iOS 上会怎样」
时要区分开，别把这份当成 Darwin 实现来讲。

## 构建

SwiftPM（`Package.swift`）+ CMake。本工作区定位为只读研究，不构建。
