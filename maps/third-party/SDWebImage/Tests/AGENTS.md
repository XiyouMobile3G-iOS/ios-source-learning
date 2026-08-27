# SDWebImage 测试模块 —— 用例定位

`third-party/SDWebImage/Tests/`，SDWebImage **5.21.7**。

**用途**：SDWebImage 的很多行为（缓存过期、取消语义、变换 key、LIFO 顺序）在实现里散落多处，
用例是上游对这些行为的确切定义。`grep -n` 到相关 `- test...` 方法看那十几行即可，不要通读。

| 文件 | 覆盖什么 |
|---|---|
| `Tests/SDWebImageManagerTests.m` | 加载全流程、失败 URL 黑名单、取消语义、选项组合 |
| `Tests/SDImageCacheTests.m` | 内存/磁盘读写、过期清理、容量、thumbnail key |
| `Tests/SDWebImageDownloaderTests.m` | 并发上限、请求合并、**LIFO 顺序（`test15DownloaderLIFOExecutionOrder`，实现侧注释也点名了它）**、渐进式解码 |
| `Tests/SDWebCacheCategoriesTests.m` | UI 分类：设图、取消、operation key |
| `Tests/SDImageCoderTests.m` | 各格式编解码、强制解码、降采样 |
| `Tests/SDAnimatedImageTest.m` | 动图容器、播放器、帧池 |
| `Tests/SDImageTransformerTests.m` | 变换实现与**变换后的缓存 key 规则** |
| `Tests/SDWebImagePrefetcherTests.m` | 批量预取的并发与回调 |
| `Tests/SDCategoriesTests.m` | `NSData+ImageContentType` 等分类 |
| `Tests/SDUtilsTests.m` | `SDCallbackQueue`、`SDWeakProxy`、`SDFileAttributeHelper` 等内部工具 |
| `Tests/SDTestCase.{h,m}` | 基类：测试图片 URL、超时常量 |
| `Tests/SDWebImageTestCache.{h,m}`、`TestLoader`、`TestCoder`、`TestTransformer`、`TestDownloadOperation` | **自定义实现的样例**——想看「怎么替换缓存/加载器/编解码器」，这几份比文档直观 |
| `Tests/SDMockFileManager.{h,m}` | 模拟磁盘失败 |
| `Tests/Images/` | 各格式测试图 |

---

## 注意

- 本工作区只读研究，**不要尝试构建或运行用例**（需要 Examples 工程与网络）。
- 那五个 `SDWebImageTest*` 文件是协议化架构最好的入口：它们展示了实现 `SDImageCache` /
  `SDImageLoader` / `SDImageCoder` 协议各需要哪些方法，比读协议头文件更快。
- 实现侧符号表在 [`../SDWebImage/Core/AGENTS.md`](../SDWebImage/Core/AGENTS.md) 与 [`../SDWebImage/Private/AGENTS.md`](../SDWebImage/Private/AGENTS.md)。
