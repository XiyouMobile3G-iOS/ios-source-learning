# GNUstep base 1.31.1 —— 文件地图

**这不是 Apple 的代码。** GNUstep 是 OpenStep/Cocoa 规范的独立开源重实现（LGPL），
1994 年起由社区维护。放进本工作区只有一个理由：

> Apple 从未开源过 Foundation 的 Objective-C 实现。开源出来的只有 CoreFoundation
> （`../CF-1153.18-apple/`）和 Swift 版（`../swift-corelibs-foundation/` + `../swift-foundation/`）。
> **`NSNotificationCenter` / `NSRunLoop` 的 ObjC 层 / KVO 的 isa-swizzling，Apple 侧一行源码都没有。**

所以这份是**参照实现**：行为按 OpenStep 规范对齐，机制思路与逆向 Apple Foundation 得到的
结论基本吻合，但**实现细节不保证与 Apple 一致**。引用时必须写明「GNUstep base 1.31.1」，
**不得说成「Apple 的实现」**。判定规则见工作区 `AGENTS.md` 的「选型铁律」。

版本：tag `base-1_31_1`（本地同名分支，commit `6307e474d`，2025-02-28）。本文行号按此 tag。
规模：`Source/*.m` 共 204015 行。**不要整读任何一个文件**，用下面的行号 + `Read` 的 `offset`/`limit`。

---

## 通知中心 —— `Source/NSNotificationCenter.m`（1373 行）

本工作区引入 GNUstep 的**首要目标**。三张表 + 一个观察记录链表，是理解
「`postNotificationName:object:` 到底查了几次表」的最短路径。

### 数据结构

| 结构 | 行号 | 说明 |
|---|---|---|
| `typedef struct Obs`（`Observation`） | `147` | 一次 `addObserver` 产生一条；字段注释在 `126-145` |
| ↑ `observer` 是**弱引用**，`receiver` 只在投递期间强持有 | `148` / `149` | 注释见 `135-139` |
| `#define ENDOBS ((Observation*)-1)` —— 链表结束哨兵，**不是 NULL** | `157` | 易踩：`next == 0` 表示「未使用」，`ENDOBS` 才是表尾 |
| `typedef struct NCTbl`（`NCTable`） | `244` | 中心的全部状态 |

`NCTable` 三条投递路径（`245-247`）：

| 字段 | 宏 | 命中条件 |
|---|---|---|
| `wildcard`（`Observation*` 链表） | `WILDCARD` `259` | name 和 object 都为 nil —— 收所有通知 |
| `nameless`（`GSIMapTable`） | `NAMELESS` `260` | 只指定了 object，不指定 name |
| `named`（`GSIMapTable`，值又是一张 `GSIMapTable`） | `NAMED` `261` | 指定了 name；**两级映射** name → object → 链表 |

`GSIMapTable` 是 GNUstep 的内联哈希表模板：宏配置在 `205-222`，`224` 行 `#include`
把模板展开进来，模板本体在 `Headers/GNUstepBase/GSIMap.h`。键的 hash/equal 走
`doHash` `159` / `doEqual` `175`——`shouldHash` 为 NO 时**按指针比较**（object 键就是这么走的）。

`Observation` 不走 `malloc`/`free`，而是从 `CHUNKSIZE=128`（`242`）的块池里取、还回 freeList。
`226-241` 的注释明说了代价：**注册过大量 observer 后，内存不会再回落**，换的是增删速度。

### 注册

| 内容 | 行号 |
|---|---|
| `-addObserver:selector:name:object:` | `813` |
| ↑ 加锁 `lockNCTable` | `839` |
| ↑ `obsNew` 从 chunk 池分配 `Observation`（`264`） | `841` |
| ↑ ↑ **`objc_initWeak(&obs->observer, o)`** —— observer 存的是**弱引用** | `308` |
| ↑ **具名分支**：`GSIMapNodeForKey(NAMED, name)` | `855` |
| ↑ ↑ name 首次出现，建二级表并挂上 | `864` |
| ↑ **无名分支**：`GSIMapNodeForSimpleKey(NAMELESS, object)` | `890` |
| ↑ **通配分支**：头插进 `WILDCARD` 链表 | `905-906` |
| ↑ 解锁 | `909` |
| `-addObserverForName:object:queue:usingBlock:` | `925` |

block 版不是另一套机制：它包一个 `GSNotificationObserver`（`633` 声明 / `641` 实现），
回调走 `-didReceiveNotification:` `669`，再由 `GSNotificationBlockOperation`（`595` / `606`）
丢进 `NSOperationQueue`。**「block 版 observer 返回的那个 token 必须自己 remove」的根因就在这里**——
真正注册进表的是这个内部对象，不是你的 self。

### 投递 —— `-_postAndRelease:`（`1172`，全中心最该读的一段）

分两段：**持锁收集**，**解锁后调用**。

| 内容 | 行号 |
|---|---|
| 栈上 64 槽数组，避免小规模投递走堆 | `1180-1182` / `1200` |
| 加锁 | `1202` |
| ① `WILDCARD` 链表全收 | `1206` |
| ② `NAMELESS` 按 object 查 | `1212` |
| ③ `NAMED` 查 name 拿二级表 | `1230` |
| ↑ ③a 二级表里 object 精确匹配 | `1243` |
| ↑ ③b 二级表里 object 为 nil 的（`1255` 判断 **object != nil 才查**） | `1259` |
| **解锁** | `1276` |
| 倒序遍历数组，`performSelector:withObject:` | `1280-1288` |
| 每次调用包 `NS_DURING` / `NS_HANDLER`——**单个 observer 抛异常不中断其余投递** | `1286` / `1291` |
| 收尾清空数组（重新加锁） | `1316-1318` |

`addPost`（`1120`）负责把一条链表整体追加进待投递数组，顺带做**惰性垃圾回收**：
`1138` 用 `objc_loadWeakRetained` 把弱引用提升为临时强引用写进 `o->receiver`——
提得上来就进投递数组（`1142`），提不上来说明 observer 已经 dealloc，
走 `1145` 的 `else` 分支就地摘链并 `obsFree`（`1159`）。
**过期观察记录不是在 dealloc 时清的，是在下一次 post 路过时顺手清的**——
这就是「忘了 removeObserver 也不会野指针」在这份实现里的机制。

同时它对每个 `Observation` 做 `obsPost`（`494`）增加 posting 计数——**这就是「投递过程中 removeObserver 不会崩」的机制**：
链表节点在投递期间不会真正释放，只标记，等 posting 归零由 `obsDone`（`474`）回收。

`postNotification:` `1332` / `postNotificationName:object:` `1346` / `...userInfo:` `1359`
都只是薄封装，全部落到 `_postAndRelease:`。

> **坑：`1352-1358` 的文档注释是过时的，且结论与代码相反。**
> 它给 `postNotificationName:object:userInfo:`（`1359`）写的说明是：
> *「For performance reasons, we don't wrap an exception handler round every message sent
> to an observer. This means that, if one observer raises an exception, later observers in
> the lists will not get the notification.」*（原文在 `1355-1357`）
>
> 但 `1286` 的 `NS_DURING` / `1291` 的 `NS_HANDLER` 明明把**每一次** `performSelector` 都包住了，
> 捕获后只打日志并继续循环。**以代码为准：这一版里单个 observer 抛异常不影响其余 observer。**
> 只查注释会得到完全相反的答案。
>
> 注意这条只对 GNUstep 成立。Apple 平台不吞异常，后续 observer 收不到——那正是这段旧注释
> 描述的语义，但**本工作区没有任何源码能证明 Apple 侧的行为**，引用时必须标注为行为性结论。

### 注销

| 内容 | 行号 |
|---|---|
| `-removeObserver:name:object:` | `953` |
| `-removeObserver:` —— 三张表全扫 | `1112` |
| `listPurge` —— 从链表摘除某 observer | `519` |

### 单例与锁

| 内容 | 行号 |
|---|---|
| `+defaultCenter` | `744` |
| `default_center` 静态变量 | `711` |
| `lockNCTable` / `unlockNCTable`（`NSRecursiveLock`，带 `lockCount`） | `430` / `436` |

**锁是递归锁**：observer 回调里再 post 一次通知不会自锁死。

---

## 通知配套

| 文件 | 行数 | 内容 |
|---|---|---|
| `Source/NSNotification.m` | 207 | `NSNotification` 本体，极薄 |
| `Source/NSNotificationQueue.m` | 700 | 合并与延迟投递。`enqueueNotification:postingStyle:` `484` / `:coalesceMask:forModes:` `505`；`dequeueNotificationsMatching:` `391`；与 RunLoop 的咬合在 `NotificationQueueList` `77` |
| `Source/NSDistributedNotificationCenter.m` | 842 | 跨进程通知，走 DO；**iOS 上没有，只作对照** |

`NSNotificationQueue` 是「`NSPostWhenIdle` 为什么要等 RunLoop 空闲」的答案所在，
跟 `../CF-1153.18-apple/CFRunLoop.c` 的 mode 概念对照读。

---

## 其余高价值文件（Apple 侧同样无源码）

只给文件与已核对的锚点，细节按需 `grep -n`。

| 主题 | 文件（行数） | 已核对锚点 |
|---|---|---|
| **KVO**（isa-swizzling 全流程） | `Source/NSKeyValueObserving.m`(2227) | `GSKVOBase` `208`、`GSKVOReplacement`（动态子类工厂）`429`、`GSKVOSetter` `711`、`GSKVOInfo` `1099`；`-addObserver:forKeyPath:options:context:` `1528`、`willChangeValueForKey:` `1793`、`didChangeValueForKey:` `1846` |
| KVC | `Source/NSKeyValueCoding.m`(950) | —— |
| **RunLoop 的 ObjC 层** | `Source/NSRunLoop.m`(1596) | `@implementation NSRunLoop` `758`、`addTimer:` `886`、`limitDateForMode:` `1139`、`acceptInputForMode:` `1177`、`runMode:beforeDate:` `1302`、`run` `1358` |
| **自动释放池** | `Source/NSAutoreleasePool.m`(706) | `@implementation NSAutoreleasePool` `130`、`emptyPool` `282`、`+_endThread:` `651` |
| NSObject / 引用计数 | `Source/NSObject.m`(2682) | —— |
| NSOperation / 队列 | `Source/NSOperation.m`(1184) | —— |
| NSThread | `Source/NSThread.m`(2496) | —— |
| NSTimer | `Source/NSTimer.m`(450) | —— |

其他目录：`Headers/Foundation/`（公开头）、`Headers/GNUstepBase/`（内部）、
`Source/Additions/`（`GSIMap.h` 等内联模板的使用方）、`Source/{unix,win32}/`（平台后端）、
`Tests/`（行为用例，**验证「规范要求什么」时比读实现快**）。

---

## 与 Apple 侧的对应关系

| 想搞清楚 | 本仓库 | Apple 侧有没有 |
|---|---|---|
| NSNotificationCenter 怎么存 observer、怎么分发 | `Source/NSNotificationCenter.m` | **没有**（CF 里的 `CFUserNotification.c` 是弹框，无关） |
| KVO 动态子类怎么生成 | `Source/NSKeyValueObserving.m` | **没有**（只能对照 `../new objc4/` 的类与 isa 机制反推） |
| RunLoop 内核循环 | `Source/NSRunLoop.m`（ObjC 层，**非权威**） | **有且权威**：`../CF-1153.18-apple/CFRunLoop.c` |
| 自动释放池底层 | `Source/NSAutoreleasePool.m`（**非权威**） | **有且权威**：`../new objc4/runtime/NSObject.mm` |

**RunLoop 和自动释放池一律以 Apple 侧为准**，GNUstep 这两份只在「ObjC 封装层长什么样」时参考。
通知中心和 KVO 才是这份仓库不可替代的部分。

## 构建

`configure` + `GNUmakefile`，需要 gnustep-make 与 libobjc2。**本工作区定位为只读研究，不构建。**
