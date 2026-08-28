# SDWebImage —— 模块索引

`SDWebImage/SDWebImage`，钉在 **tag `5.21.7`**（本地分支同名 `5.21.7`）。所有子文档的行号都按 5.21.7 写。

**本文件只做路由与跨模块串联，不放符号表。**

5.x 全面协议化：缓存（`SDImageCache`）、加载（`SDImageLoader`）、编解码（`SDImageCoder`）都可替换，
`SDWebImageManager` 只是把三者串起来的协调者。**按 4.x 的博客理解 5.x 几乎必错。**

---

## 按任务定位

| 问题涉及 | 去读 |
|---|---|
| 缓存查询/写入、下载调度、协调流程、编解码、变换、UI 分类、动图 | [`SDWebImage/Core/AGENTS.md`](./SDWebImage/Core/AGENTS.md) |
| 动图播放引擎、`SDDisplayLink`、弱代理、异步 operation、文件属性 | [`SDWebImage/Private/AGENTS.md`](./SDWebImage/Private/AGENTS.md) |
| Core / Private / include / Resources 的分工，头文件副本陷阱 | [`SDWebImage/AGENTS.md`](./SDWebImage/AGENTS.md) |
| `MKAnnotationView` 上加载图片 | [`SDWebImageMapKit/MapKit/AGENTS.md`](./SDWebImageMapKit/MapKit/AGENTS.md) |
| 某行为的确切边界（缓存过期、取消语义、变换 key） | [`Tests/AGENTS.md`](./Tests/AGENTS.md) |

`Examples/` `Docs/` `Configs/` `Scripts/` `WebImage/` 与源码研究无关。

---

## 模块划分

| 目录 | 行数 | 角色 |
|---|---|---|
| `SDWebImage/Core/` | 约 15000（.m） | **核心**，60+ 文件，内部再分七个主题 |
| `SDWebImage/Private/` | 约 2400 | 内部工具，不对外暴露 |
| `SDWebImageMapKit/MapKit/` | 241 | 可选子库 |
| `Tests/Tests/` | 15 个用例文件 | 行为边界依据 |

---

## 跨模块：一次 `sd_setImageWithURL:` 的完整链路

**这条链跨文件跨模块，只在这里记**，各段细节回对应模块文档查：

1. `Core/UIView+WebCache.m:58` `sd_internalSetImageWithURL:...` —— 所有 UI 分类的**唯一收口**
2. `Core/UIView+WebCacheOperation.m:54` 取消同 key 的旧请求 → 设占位图 → `UIView+WebCache.m:486` 启动 indicator
3. `Core/SDWebImageManager.m:189` `loadImageWithURL:options:context:progress:completed:`
4. `:283` 查缓存 → `Core/SDImageCache.m:572` `queryCacheOperationForKey:`（先内存后磁盘）
5. 未命中 → `SDWebImageManager.m:403` 下载 → `Core/SDWebImageDownloader.m:197` → `Core/SDWebImageDownloaderOperation.m:170`
6. 解码 → `Core/SDImageCoderHelper.m:652` `decodedImageWithImage:policy:`
7. `SDWebImageManager.m:496` 变换 → `:607` 回写缓存 → `:707` 回调
8. 回到 `UIView+WebCache.m:296` 设置图片 + 转场动画

回调线程由 `Core/SDCallbackQueue.m` 决定，默认主队列。

## 跨模块：与底层的咬合

- **RunLoop**：动图播放靠 `Private/SDDisplayLink.m:174` `addToRunLoop:forMode:`，
  mode 的语义见 `../../CF-1153.18-apple/AGENTS.md`
- **GCD**：磁盘 IO 在 `Core/SDImageCache.m:131` 的串行 `ioQueue` 上；回调派发见 `Core/SDCallbackQueue.m`
- **NSOperation**：下载并发与 LIFO 靠 `NSOperationQueue` + `addDependency:`（`Core/SDWebImageDownloader.m:391`）

---

## 版本纪律与全局陷阱

- 钉在 `5.21.7`，`update-sources.sh` 只 fetch 报告，不切换版本。
- **`Core/` 与 `include/SDWebImage/` 是同一份头文件的两个副本**，grep 结果必然翻倍，**行号一律引 `Core/`**。
- 引用写成 `SDImageCache.m:572`（SDWebImage 5.21.7）。
