# SDWebImage 核心模块 —— 文件地图

`third-party/SDWebImage/SDWebImage/Core/`，SDWebImage **5.21.7**。行号按此 tag。

60+ 文件、约 15000 行（.m），**禁止整目录展开**。按下面七个主题选一个再读。
跨模块链路在 [`../../AGENTS.md`](../../AGENTS.md)；`include/SDWebImage/` 是本目录头文件的副本，**行号一律引本目录**。

| 主题 | 主要文件 | 往下看第几节 |
|---|---|---|
| 协调 | `SDWebImageManager` `SDWebImageDefine` `SDWebImagePrefetcher` | 1 |
| 缓存 | `SDImageCache` `SDMemoryCache` `SDDiskCache` `SDImageCachesManager` | 2 |
| 下载 | `SDWebImageDownloader` `SDWebImageDownloaderOperation` `SDImageLoader` | 3 |
| 编解码 | `SDImageCoder*` `SDImageCoderHelper` `NSData+ImageContentType` | 4 |
| 变换 | `SDImageTransformer` `UIImage+Transform` | 5 |
| UI 分类 | `UIView+WebCache` 及各控件分类、指示器、转场 | 6 |
| 动图 | `SDAnimatedImage` `SDAnimatedImageView` `SDAnimatedImagePlayer` | 7 |

---

## 1. 协调层

`SDWebImageManager.m`（816 行）是整个库的调度中心，一次加载被拆成六个 `call*Process` 串起来：

| 符号 | 行 | 说明 |
|---|---|---|
| `+ sharedManager` | 66 | 默认 cache/loader 在 18-19，可全局替换（48 / 59） |
| `- initWithCache:loader:` | 87 | **协议注入点**：任何实现 `SDImageCache`/`SDImageLoader` 协议的对象都能塞进来 |
| `- cacheKeyForURL:context:` | 136 | 默认 key = URL 绝对串，可被 `cacheKeyFilter` 改写；变换前原图 key 见 116 |
| `- loadImageWithURL:options:context:progress:completed:` | 189 | **总入口**，返回 `SDWebImageCombinedOperation`（788，`- cancel` 797） |
| `- callCacheProcessForOperation:` | 283 | ① 查缓存 |
| `- callOriginalCacheProcessForOperation:` | 342 | ② 变换图未命中时回查原图 |
| `- callDownloadProcessForOperation:` | 403 | ③ 下载 |
| `- callTransformProcessForOperation:` | 496 | ④ 变换 |
| `- callStoreOriginCacheProcessForOperation:` | 552 | ⑤ 存原图 |
| `- callStoreCacheProcessForOperation:` | 607 | ⑥ 存结果 |
| `- callCompletionBlockForOperation:` | 699 / 707 | ⑦ 回调（队列由 `SDCallbackQueue` 决定，默认主队列） |
| `- shouldBlockFailedURLWithURL:` | 723 | **失败 URL 黑名单**；`SDWebImageRetryFailed` 绕过它 |
| `- safelyRemoveOperationFromRunning:` | 648 | |
| `- processedResultForURL:options:context:` | 746 | 交给 `SDWebImageOptionsProcessor` 统一改写选项 |

配套：`SDWebImageDefine.m`（163，选项与 context key 定义）、`SDWebImageOptionsProcessor.m`（59）、
`SDWebImagePrefetcher.m`（341，批量预取）、`SDCallbackQueue.m`（118：`+mainQueue` 59、`+currentQueue` 65、`- async:` 98）。

---

## 2. 缓存

`SDImageCache.m`（1031 行）是内存 + 磁盘的门面：

| 符号 | 行 | 说明 |
|---|---|---|
| `+ sharedImageCache` | 85 | |
| `- initWithNamespace:diskCacheDirectory:config:` | 118 | 建内存与磁盘两层 |
| `_ioQueue = dispatch_queue_create(...)` | 131 | **所有磁盘 IO 走这条串行队列**（属性 76） |
| `- queryCacheOperationForKey:options:context:done:` | 572 | **读主路径**：先内存后磁盘，返回可取消的 `SDImageCacheToken`（38，`- cancel` 48） |
| `- storeImage:imageData:forKey:options:context:cacheType:completion:` | 236 | **写主路径**，内存/磁盘分支判断在 249 |
| `- storeImageToMemory:forKey:` / `- storeImageDataToDisk:forKey:` | 354 / 362 | |
| `- imageFromMemoryCacheForKey:` / `- imageFromDiskCacheForKey:options:context:` | 440 / 448 | |
| `- diskImageDataExistsWithKey:` | 395 | **`dispatch_sync` 到 ioQueue，主线程调用会阻塞** |
| `- migrateDiskCacheDirectory` | 192 | 老版本目录迁移 |
| `SDIsThumbnailKey()` | 22 | 缩略图 key 识别（5.x 的 thumbnail 支持） |

`SDMemoryCache.m`（158）：`NSCache` 子类 + **强键弱值的 `weakCache`**（24，建于 66，读写 86/99），
作用是「`NSCache` 因内存警告清空后，仍被 UI 持有的图片还能找回」，由 `config.shouldUseWeakMemoryCache` 控制；
`- didReceiveMemoryWarning:` 78。

`SDDiskCache.m`（390）：`- removeExpiredData` 151（**先按过期时间、再按总大小两轮清理**）、
`SDDiskCacheFileNameForKey()` 360（URL → MD5 文件名）、`- containsDataForKey:` 50、
扩展属性存元数据 102 / 113、`- moveCacheDirectoryFromPath:toPath:` 293。

`SDImageCachesManager.m`（575）多缓存串联，配合 `../Private/SDImageCachesManagerOperation.m` 计数完成；
配置项在 `SDImageCacheConfig.m`（72）、协议与工具在 `SDImageCacheDefine.m`（153）。

---

## 3. 下载

`SDWebImageDownloader.m`（665）负责调度：

| 符号 | 行 | 说明 |
|---|---|---|
| `+ sharedDownloader` | 80 | |
| `- initWithConfig:` | 93 | 101-103 建 `downloadQueue`，并发数取 `config.maxConcurrentDownloads` |
| `- downloadImageWithURL:options:context:progress:completed:` | 197 | **同 URL 请求合并到同一 operation** |
| `- createDownloaderOperationWithUrl:options:context:` | 290 | |
| LIFO 实现 | 391-396 | **不是队列自带能力**：让已排队的 operation `addDependency:` 新 operation |
| `- operationWithTask:` | 439 | session delegate 转发的落点（459-537 是各回调） |
| `- cancelAllDownloads` / `- setSuspended:` | 403 / 413 | |

`SDWebImageDownloaderOperation.m`（762）是单个任务：
`- start` 170、`- cancel:`（按 token）147、`- cancelInternal` 272、`- done` 301、
`- URLSession:dataTask:didReceiveResponse:` 430、**`didReceiveData:` 515（渐进式解码入口，取 coder 在 379）**、
`- startCoderOperationWithImageData:` 362（解码不占 delegate 队列）、`didCompleteWithError:` 607、
`didReceiveChallenge:` 670、`- shouldContinueWhenAppEntersBackground` 721、
`SDWebImageDownloaderOperationToken` 26（一个 operation 多个调用方的凭据）。

抽象层：`SDImageLoader.m`（178，协议默认实现与工具函数）、`SDImageLoadersManager.m`（123）、
请求/响应改写与解密：`SDWebImageDownloaderRequestModifier.m`（71）、`...ResponseModifier.m`（73）、`...Decryptor.m`（55）、
配置 `SDWebImageDownloaderConfig.m`（60）。

---

## 4. 编解码

`SDImageCoderHelper.m`（1106）是图像处理工具箱，**性能问题基本都落在这里**：

| 符号 | 行 | 说明 |
|---|---|---|
| `+ decodedImageWithImage:policy:` | 652（无 policy 版 648） | **强制解码**，避开首次绘制的隐式解码卡顿 |
| `+ decodedAndScaledDownImageWithImage:limitBytes:policy:` | 721（简版 717） | 超大图降采样 |
| `+ CGImageCreateDecoded:orientation:` | 436 | |
| `+ CGImageCreateScaled:size:` | 482 | |
| `+ scaledSizeWithImageSize:limitBytes:bytesPerPixel:frameCount:` | 635 | 内存上限反推尺寸 |
| `+ CGImageIsHardwareSupported:` | 330 | 判断是否需要重绘对齐 |
| `+ CGImageContainsAlpha:` / `+ CGImageIsLazy:` / `+ CGImageIsHDR:` | 368 / 379 / 418 | |
| `+ preferredPixelFormat:` | 307 | 字节对齐 |
| `+ animatedImageWithFrames:` / `+ framesFromAnimatedImage:` | 144 / 207 | 帧数组 ↔ 动图 |
| `+ defaultDecodeSolution` | 871 | |

格式与分派：`NSData+ImageContentType.m`（167：`+sd_imageFormatForImageData:` 22 靠**魔数**判格式）、
`SDImageCodersManager.m`（145：`- decodedImageWithData:options:` 101 按注册顺序问每个 coder）、
`SDImageCoder.h`（347，协议定义，含渐进式解码协议）。

具体 coder：`SDImageIOCoder.m`（458，静态图）、`SDImageIOAnimatedCoder.m`（1158，**动图基类**）、
`SDImageGIFCoder.m`（58）/`SDImageAPNGCoder.m`（58）/`SDImageHEICCoder.m`（109）/`SDImageAWebPCoder.m`（98）都只是它的薄子类。
绘图上下文：`SDImageGraphics.m`（126）、`SDGraphicsImageRenderer.m`（229）；
元数据 `UIImage+Metadata.m`（236）、多格式便捷 `UIImage+MultiFormat.m`（61）、macOS 兼容 `NSImage+Compatibility.m`（120）。

---

## 5. 变换

`SDImageTransformer.m`（375）定义变换协议与链式组合（`SDImagePipelineTransformer`），
**变换后的图用带变换 key 的缓存 key 存**，这是「同一 URL 多份缓存」的来源，对照 `SDWebImageManager.m:116/136`。
`UIImage+Transform.m`（1064）是具体实现：圆角、缩放、裁剪、旋转、翻转、色调、模糊、滤镜。

---

## 6. UI 分类

| 文件 | 行数 | 说明 |
|---|---|---|
| `UIView+WebCache.m` | 508 | **唯一收口**：`- sd_internalSetImageWithURL:...` 58；设图与转场 296；`- sd_setNeedsLayout` 438；指示器 486/496 |
| `UIView+WebCacheOperation.m` | 85 | **按 key 存取/取消 operation**：`- sd_imageLoadOperationForKey:` 30、`- sd_setImageLoadOperation:forKey:` 42、`- sd_cancelImageLoadOperationWithKey:` 54 |
| `UIView+WebCacheState.m` | 56 | 多 state 控件的状态存储 |
| `UIImageView+WebCache.m` | 78 | 全部转调 `UIView+WebCache` |
| `UIImageView+HighlightedWebCache.m` | 88 | |
| `UIButton+WebCache.m` | 201 | 按 `UIControlState` 分别加载 |
| `NSButton+WebCache.m` | 162 | macOS |
| `SDWebImageIndicator.m` | 291 | 菊花/进度指示器 |
| `SDWebImageTransition.m` | 194 | 转场动画配置 |

**取消逻辑的关键**：`UIView+WebCacheOperation.m:54` 按 operation key 取消，key 默认是分类名（如 `UIImageViewImageLoad`），
所以同一个 view 上换 URL 会自动取消上一个请求——cell 复用错图问题从这里查。

---

## 7. 动图

`SDAnimatedImage.m`（449）容器 + `SDAnimatedImageView.m`（628）视图 + `SDAnimatedImagePlayer.m`（355）播放器 +
`SDAnimatedImageRep.m`（151，macOS）+ `SDAnimatedImageView+WebCache.m`（79）。

**帧调度与时钟不在这里**，在 `../Private/`（`SDDisplayLink`、`SDImageFramePool`），见 [`../Private/AGENTS.md`](../Private/AGENTS.md)。
排查加载/缓存问题时**不要展开本主题**，它与主链路无关。

---

## 易错点

- 缓存 key 默认是完整 URL（`SDWebImageManager.m:136`）；带签名/时效参数的 URL 会导致缓存永不命中。
- `SDImageCache.m:395` 等几个 `dispatch_sync(ioQueue, ...)` 是同步 API，主线程调用会卡。
- LIFO 是 `SDWebImageDownloader.m:391-396` 用反向依赖模拟的，不是 `NSOperationQueue` 的能力。
- 变换图与原图是两个缓存条目（`SDWebImageManager.m:116` vs `:136`），排查「变换不生效」先确认查的是哪个 key。
- 渐进式解码走的是另一条路（`SDWebImageDownloaderOperation.m:379/515`），与最终解码不是同一次调用。
