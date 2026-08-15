# AFNetworking UIKit 模块 —— 文件地图

`third-party/AFNetworking/UIKit+AFNetworking/`，AFNetworking **4.0.1**。行号按此 tag。

本模块单向依赖核心模块（[`../AFNetworking/AGENTS.md`](../AFNetworking/AGENTS.md)），核心不反过来依赖它。
两块内容：**图片下载与缓存**、**UIKit 分类**。

| 文件 | 行数 | 职责 |
|---|---|---|
| `AFImageDownloader.m` | 421 | 图片下载器：请求合并 + 并发控制 + 优先级队列 |
| `AFAutoPurgingImageCache.m` | 205 | 内存图片缓存，超限按 LRU 清理 |
| `UIButton+AFNetworking.m` | 302 | 按 `UIControlState` 分别下载 |
| `AFNetworkActivityIndicatorManager.m` | 239 | 状态栏菊花 |
| `UIImageView+AFNetworking.m` | 159 | 最常用入口 |
| `WKWebView+AFNetworking.m` | 154 | 用 AFN 的 session 加载网页 |
| `UIProgressView+AFNetworking.m` | 126 | 进度条绑定 task |
| `UIActivityIndicatorView+AFNetworking.m` | 114 | 菊花绑定 task |
| `UIRefreshControl+AFNetworking.m` | 113 | 下拉刷新绑定 task |

---

## 图片下载器 `AFImageDownloader.m`

### 三个并发结构

| 符号 | 行 | 说明 |
|---|---|---|
| `synchronizationQueue` | 98（建于 179） | **串行队列**，所有内部状态读写都在它上面 |
| `responseQueue` | 99（建于 182） | **并发队列**，回调用户的 block |
| `queuedMergedTasks` | 104 | 排队中的任务数组，配合优先级策略取任务 |
| `maximumActiveDownloads` | 101 | 默认 **4**（见 159） |
| `downloadPrioritization` | 170 | 默认 **FIFO**（见 158），可切 LIFO |

### 请求合并

| 符号 | 行 | 说明 |
|---|---|---|
| `AFImageDownloaderResponseHandler` | 29 | 一次调用的回调载体（UUID + success/failure） |
| `AFImageDownloaderMergedTask` | 54 | **同一 URL 的多次请求合并成一个 task**，`- addResponseHandler:` 74 |
| `AFImageDownloadReceipt` | 84 | 返回给调用方的凭据，用它取消 |
| `- downloadImageForURLRequest:withReceiptID:success:failure:` | 203 | **主入口**：`:208` 先 `dispatch_sync` 进同步队列判重 |
| `- cancelTaskForImageDownloadReceipt:` | 319 | 按凭据取消**单个** handler，其余共享者不受影响 |
| `- safelyRemoveMergedTaskWithURLIdentifier:` | 347 | |
| `- safelyStartNextTaskIfNecessary` | 370 | 活跃数 < 上限时按优先级出队 |
| `- startMergedTask:` / `- enqueueMergedTask:` | 384 / 389 | |
| `+ defaultURLCache` | 111 | 自带 `NSURLCache`（内存 20MB / 磁盘 150MB 量级，以代码为准） |

### 内存缓存 `AFAutoPurgingImageCache.m`

用**并发队列 + barrier** 实现读写锁，这是本文件的看点：

| 符号 | 行 | 说明 |
|---|---|---|
| `synchronizationQueue` | 70（建于 86，`DISPATCH_QUEUE_CONCURRENT`） | |
| `- addImage:withIdentifier:` | 110 | `:111` `dispatch_barrier_async` 写 |
| 清理判定 | 123-125 | 超 `memoryCapacity` 就清到 `preferredMemoryUsageAfterPurge` |
| `- imageWithIdentifier:` | 170 | `:172` `dispatch_sync` 读 |
| `- removeImageWithIdentifier:` / `- removeAllImages` | 145 / 158 | `dispatch_barrier_sync` |
| `AFCachedImage` | 28 | 记 `lastAccessDate`（`- accessImage` 54），LRU 依据 |
| `- imageCacheKeyFromURLRequest:withAdditionalIdentifier:` | 191 | 缓存 key 规则 |

---

## UIKit 分类

统一套路：**分类里用关联对象存下载凭据 → 新请求先判是否同 URL → 不同则取消旧的**。

| 符号 | 行 | 说明 |
|---|---|---|
| `UIImageView (_AFNetworking)` | 30 | 私有分类存 `af_activeImageDownloadReceipt`（36/40） |
| `- setImageWithURLRequest:placeholderImage:success:failure:` | 73 | **真正干活的一份**，60/64 是便捷方法 |
| `- isActiveTaskURLEqualToURLRequest:` | 153 | 同 URL 就不重复请求 |
| `- cancelImageDownloadTask` | 142 | |
| `+ sharedImageDownloader` | 50 | 全局下载器，可替换（54） |
| `af_imageDownloadReceiptKeyForState()` | `UIButton+AFNetworking.m:43` | **按 `UIControlState` 分四个关联 key**（38-41），背景图另四个（69-74） |
| `- setImageForState:withURLRequest:...` | 同上 `:131` | 背景图对应 `:210` |
| `- loadRequest:navigation:progress:success:failure:` | `WKWebView+AFNetworking.m:107` | 用 AFN session 拉 HTML 再交给 WebKit |

## 菊花管理 `AFNetworkActivityIndicatorManager.m`

**与核心模块之间只有通知这一条线**（核心在 `AFURLSessionManager.m:425/435` 的 swizzle 里发通知）：

| 符号 | 行 | 说明 |
|---|---|---|
| `- networkRequestDidStart:` / `- networkRequestDidFinish:` | 142 / 148 | 通知订阅入口 |
| `- incrementActivityCount` / `- decrementActivityCount` | 124 / 133 | 引用计数 |
| `- updateCurrentStateForNetworkActivityChange` | 180 | 状态机核心 |
| 激活延迟 1.0s / 完成延迟 0.17s | 34 / 35 | **防止请求密集时菊花闪烁**，定时器 205-233 |

---

## 易错点

- `AFImageDownloader` 的取消是**按 receipt 取消 handler**（319），不是取消底层 task；同 URL 的其他调用方仍会拿到图片。
- 缓存与下载是两层：`AFAutoPurgingImageCache` 只管内存，磁盘复用的是 `NSURLCache`（111）——**没有 SDWebImage 那样的独立磁盘缓存与解码器体系**，对照见 [`../../SDWebImage/AGENTS.md`](../../SDWebImage/AGENTS.md)。
- `UIButton` 的四个 state 各有独立凭据（38-41、69-74），只取消 normal 态不会影响其他 state。
- 菊花计数依赖通知，而通知来自 swizzle；关掉或未触发 swizzle 时菊花会不动。
