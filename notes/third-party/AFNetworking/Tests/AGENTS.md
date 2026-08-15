# AFNetworking 测试模块 —— 用例定位

`third-party/AFNetworking/Tests/`，AFNetworking **4.0.1**。

**用途**：当问题是「AFN 在某个边界情况下到底怎么表现」时，用例比读实现快，而且是上游认可的行为定义。
用例本身不必通读，`grep -n` 到相关 `- test...` 方法再看那十几行。

| 文件 | 覆盖什么 |
|---|---|
| `Tests/AFURLSessionManagerTests.m` | task 生命周期、delegate 映射、进度、`invalidate` 行为 |
| `Tests/AFHTTPSessionManagerTests.m` | 六个 HTTP 方法、baseURL 拼接、序列化器切换 |
| `Tests/AFHTTPRequestSerializationTests.m` | **参数编码、URL 转义、multipart 边界**（编码问题优先查这份） |
| `Tests/AFHTTPResponseSerializationTests.m` | 状态码/MIME 校验的确切边界 |
| `Tests/AFJSONSerializationTests.m` | JSON 解析、null 处理 |
| `Tests/AFXMLParserResponseSerializerTests.m`、`AFXMLDocumentResponseSerializerTests.m` | XML 两种解析 |
| `Tests/AFPropertyListRequestSerializerTests.m`、`AFPropertyListResponseSerializerTests.m` | plist |
| `Tests/AFImageResponseSerializerTests.m` | 图片解码与 scale |
| `Tests/AFCompoundResponseSerializerTests.m` | 多序列化器依次尝试的顺序 |
| `Tests/AFSecurityPolicyTests.m` | **SSL Pinning 的各种组合**，配合 `Resources/` 里的证书读 |
| `Tests/AFNetworkReachabilityManagerTests.m` | 可达性状态迁移 |
| `Tests/AFImageDownloaderTests.m` | 请求合并、并发上限、取消语义 |
| `Tests/AFAutoPurgingImageCacheTests.m` | 缓存清理阈值 |
| `Tests/AFNetworkActivityManagerTests.m` | 菊花计数与两个延迟 |
| `Tests/AFUIImageViewTests.m`、`AFUIButtonTests.m`、`AFUIRefreshControlTests.m`、`AFUIActivityIndicatorViewTests.m`、`AFWKWebViewTests.m` | UIKit 分类 |
| `Tests/AFTestCase.{h,m}` | 基类：baseURL、超时常量、公共断言 |
| `Resources/` | 测试用证书与数据文件 |

---

## 注意

- 用例跑起来需要 `Example/` 的工程与网络环境，**本工作区只读研究，不要尝试构建或运行**。
- 用例里的期望值随 drop 变化，引用时同样带 `文件:行号` + 版本号（4.0.1）。
- 实现侧的符号表在 [`../AFNetworking/AGENTS.md`](../AFNetworking/AGENTS.md) 与 [`../UIKit+AFNetworking/AGENTS.md`](../UIKit+AFNetworking/AGENTS.md)。
