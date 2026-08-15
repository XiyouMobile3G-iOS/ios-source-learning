# SDWebImage 内部模块 —— 文件地图

`third-party/SDWebImage/SDWebImage/Private/`，SDWebImage **5.21.7**。行号按此 tag。

不进 umbrella header 的实现细节，约 2400 行。**动图播放引擎在这里，不在 `Core/`**。

| 文件 | 行数 | 职责 |
|---|---|---|
| `SDmetamacros.h` | 667 | 宏元编程（`metamacro_foreach` 等），被 `SDInternalMacros.h` 依赖 |
| `SDDisplayLink.m` | 292 | **动图时钟**，跨 iOS/macOS 的 DisplayLink 抽象 |
| `SDInternalMacros.h` | 195 | `SD_LOCK` / `@weakify` / `onExit` 等内部宏 |
| `SDImageFramePool.m` | 168 | **动图帧缓冲池**，按 provider 共享 |
| `SDImageAssetManager.m` | 153 | bundle 内图片查找与缓存 |
| `SDFileAttributeHelper.m` | 127 | 扩展属性读写（磁盘缓存元数据用） |
| `SDDeviceHelper.m` | 98 | 总内存/可用内存查询 |
| `SDAsyncBlockOperation.m` | 92 | 异步 `NSOperation` 封装 |
| `SDImageCachesManagerOperation.m` | 83 | 多缓存并行查询的计数器 operation |
| `SDWeakProxy.m` | 79 | **弱引用代理**，打破 DisplayLink → target 的强引用 |
| `UIColor+SDHexString.m` | 42 | 变换 key 里颜色的字符串化 |
| `NSBezierPath+SDRoundedCorners.m` | 42 | macOS 圆角 |
| `SDAssociatedObject.m` | 29 | 关联对象工具 |
| `SDImageIOAnimatedCoderInternal.h` | 42 | 动图 coder 内部声明 |

---

## 动图播放引擎（本模块的重点）

### `SDDisplayLink.m` —— 时钟

| 符号 | 行 | 说明 |
|---|---|---|
| `- initWithTarget:selector:` | 65 | iOS 用 `CADisplayLink`，macOS 用 `CVDisplayLink`（回调 271） |
| `kSDDisplayLinkUseTargetTimestamp` | 23 | 用「下一帧」还是「上一帧」时间戳，只对 CADisplayLink 有效 |
| `- duration` | 98 | 单帧时长，动图步进的依据 |
| **`- addToRunLoop:forMode:`** | 174 | **与 RunLoop 的咬合点**：mode 决定滑动时动图是否继续播 |
| `- removeFromRunLoop:forMode:` | 197 | |
| `- start` / `- stop` | 220 / 236 | |
| `- displayLinkDidRefresh:` | 250 | 每帧回调，转发给 target |

RunLoop mode 的语义（`NSRunLoopCommonModes` vs `NSDefaultRunLoopMode`）见 `../../../../CF-1153.18-apple/AGENTS.md`。

### `SDWeakProxy.m` —— 打破强引用

`CADisplayLink` 会**强引用** target，直接 `initWithTarget:self` 会让 view 永不释放。
本类用消息转发做中转：`- forwardingTargetForSelector:` 22、`- forwardInvocation:` 26、`- methodSignatureForSelector:` 31，
并把 `class`/`isKindOfClass:`/`respondsToSelector:` 等（35-63）全部伪装成 target，使外部无感。
**这是 `NSProxy` 式弱代理的标准实现**，与 `NSTimer` 循环引用是同一类问题。

### `SDImageFramePool.m` —— 帧缓冲

| 符号 | 行 | 说明 |
|---|---|---|
| `+ registerProvider:` / `+ unregisterProvider:` | 70 / 84 | **同一图片被多个 view 播放时共享一份帧缓冲** |
| `+ providerFramePoolMap` | 30 | 全局弱表 |
| `- prefetchFrameAtIndex:` | 99 | 预解码下一帧 |
| `- setMaxConcurrentCount:` | 130 | |
| `- frameAtIndex:` / `- setFrame:atIndex:` / `- removeFrameAtIndex:` | 148 / 142 / 156 | |
| `- didReceiveMemoryWarning:` | 61 | 内存告警时丢帧 |

---

## 其它工具

- `SDAsyncBlockOperation.m`：`- start` 36、`- cancel` 56、`- complete` 67、`- isAsynchronous` 88——
  异步 operation 的三态管理（`isExecuting`/`isFinished` 手动发 KVO），是 `NSOperation` 子类化的范本。
- `SDImageCachesManagerOperation.m`：`- beginWithTotalCount:` 29、`- completeOne` 42、`- done` 53——
  给 `Core/SDImageCachesManager` 做「多个缓存都返回后才算完成」的计数。
- `SDInternalMacros.h`：`SD_LOCK` / `SD_UNLOCK` 在全库高频出现，读任何加锁代码前先看一眼它展开成什么。
- `SDDeviceHelper.m`：内存总量查询，`SDImageCache` 的默认容量按它算。

---

## 易错点

- 找动图「为什么滑动时卡住/停住」要看 `SDDisplayLink.m:174` 的 mode，而不是 `Core/` 里的播放器。
- `SDWeakProxy` 让 `isKindOfClass:` 返回的是 target 的类，**调试时看到的类型会骗人**。
- `SDmetamacros.h` 667 行纯宏，除非要读懂某个展开，否则不必打开。
