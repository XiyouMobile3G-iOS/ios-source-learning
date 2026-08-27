# AFNetworking 核心模块 —— 文件地图

`third-party/AFNetworking/AFNetworking/`，AFNetworking **4.0.1**。行号按此 tag。

6 个 `.m` 共约 4500 行，构成完整请求链路。跨模块的链路总图在 [`../AGENTS.md`](../AGENTS.md)，本文件只管本目录内部。

| 文件 | 行数 | 职责 |
|---|---|---|
| `AFURLSessionManager.m` | 1274 | session 管理、task↔delegate 映射、swizzle |
| `AFURLRequestSerialization.m` | 1399 | 请求序列化 |
| `AFURLResponseSerialization.m` | 836 | 响应序列化 |
| `AFHTTPSessionManager.m` | 357 | 业务门面 |
| `AFSecurityPolicy.m` | 341 | SSL Pinning |
| `AFNetworkReachabilityManager.m` | 269 | 可达性 |
| `AFCompatibilityMacros.h` | 49 | 平台/版本可用性宏，读实现前先扫一眼 |

---

## 1. session 管理 `AFURLSessionManager.m`

### 线程模型（面试高频，四个点缺一不可）

| 位置 | 行 | 作用 |
|---|---|---|
| `url_session_manager_processing_queue()` | 25 | **并发队列**，响应序列化在这上面做 |
| `url_session_manager_completion_group()` | 35 | 完成回调 group，供外部 `dispatch_group_notify` |
| `operationQueue.maxConcurrentOperationCount = 1` | 494 | delegate 回调队列**强制串行** |
| `dispatch_group_async(... ?: dispatch_get_main_queue())` | 210 / 236 | **回调默认回主线程**，可用 `completionQueue` 改写 |

### task ↔ delegate 映射

| 符号 | 行 | 说明 |
|---|---|---|
| `AFURLSessionManagerTaskDelegate` | 90 | 每个 task 一个，持 `mutableData` 与两个 `NSProgress` |
| `- initWithTask:` | 108 | 用 KVO 观察 `countOfBytesReceived` 等做进度 |
| `- observeValueForKeyPath:` | 156 | 进度回调的实际触发点 |
| `mutableTaskDelegatesKeyedByTaskIdentifier` | 452 | 映射表本体 |
| `self.lock = [[NSLock alloc] init]` | 506 | 保护该字典 |
| `- delegateForTask:` / `- setDelegate:forTask:` | 573 / 584 | 加锁读写 |
| `- addDelegateForDataTask:` | 596 | 上传 612、下载 627 |
| `- removeDelegateForTask:` | 649 | `:654` 移除映射，**不移除会泄漏** |

### 生命周期与 swizzle

| 符号 | 行 | 说明 |
|---|---|---|
| `- initWithSessionConfiguration:` | 481 | 唯一指定初始化器 |
| `- session` | 532 | `:536` `sessionWithConfiguration:delegate:delegateQueue:`，**session 强引用 self** |
| `- invalidateSessionCancelingTasks:resetSession:` | 700 | 打破上述循环引用的唯一出口 |
| `af_swizzleSelector()` | 330 | `method_exchangeImplementations` |
| `_AFURLSessionTaskSwizzling` | 343 | `+load` 在 349，**注释 364-379 讲清了为什么要逐层找** |
| `+ swizzleResumeAndSuspendMethodForClass:` | 407 | 沿类簇继承链找真正实现 `resume` 的类 |
| `- af_resume` / `- af_suspend` | 425 / 435 | 调原实现 + 发通知（供 UI 层菊花订阅） |
| `- respondsToSelector:` | 898 | **被重写**：按 block 是否设置动态应答，没设的让系统走默认行为 |

### 创建 task

`- dataTaskWithRequest:` 732；上传 746 / 762 / 774（streamed）；下载 787 / 799（resumeData）。

### delegate 方法行号

session 级：`didBecomeInvalidWithError:` 919、`didReceiveChallenge:` 929、`willPerformHTTPRedirection:` 945、
`task:didReceiveChallenge:` 962、`needNewBodyStream:` 1034、`didSendBodyData:` 1051、`didCompleteWithError:` 1077、
`didFinishCollectingMetrics:` 1096、`didReceiveResponse:` 1114、`didBecomeDownloadTask:` 1130、`didReceiveData:` 1145、
`willCacheResponse:` 1158、`URLSessionDidFinishEventsForBackgroundURLSession:` 1175、`didFinishDownloadingToURL:` 1186。

task 级（`AFURLSessionManagerTaskDelegate`）：`didCompleteWithError:` 173、`didFinishCollectingMetrics:` 250、
`didReceiveData:` 259、`didSendBodyData:` 269、`didWriteData:` 280、`didFinishDownloadingToURL:` 297。

---

## 2. 请求序列化 `AFURLRequestSerialization.m`

| 符号 | 行 | 说明 |
|---|---|---|
| `AFPercentEscapedStringFromString()` | 47 | URL 百分号转义；**分批处理是为绕开 emoji 上的系统 bug** |
| `AFQueryStringFromParameters()` | 119 | 参数 → 查询串；递归展开 128 / 132 |
| `AFQueryStringPair` | 81 | 键值对，`- URLEncodedStringValue` 104 |
| `- init` | 200 | 默认 header（Accept-Language / User-Agent）在此拼 |
| `AFHTTPRequestSerializerObservedKeyPaths()` | 174 | KVO 自身属性，区分「用户显式设过」与默认值 |
| `- requestWithMethod:URLString:parameters:error:` | 356 | 普通请求 |
| `- multipartFormRequestWithMethod:...` | 382 | 表单上传入口；`:419` 把 body 落盘/转流 |
| `- requestBySerializingRequest:withParameters:error:` | 475 | **GET 拼 URL / POST 进 body 的分叉点** |
| `AFCreateMultipartFormBoundary()` | 595 | 边界串；三种边界 601 / 605 / 609 |
| `AFHTTPBodyPart` | 626 | 单个表单段，`- read:` 640 |
| `AFMultipartBodyStream` | 644 | **自定义 `NSInputStream` 子类**，边读边传不撑内存 |

---

## 3. 响应序列化 `AFURLResponseSerialization.m`

| 符号 | 行 | 说明 |
|---|---|---|
| `- validateResponse:data:error:` | 110 | **状态码 200-299 + MIME 白名单**，两条校验都在这 |
| `AFJSONResponseSerializer` | 209 | 默认；解析 235，`removesKeysWithNullValues` 在此生效 |
| `AFXMLParserResponseSerializer` | 311 | |
| `AFPropertyListResponseSerializer` | 435 | |
| `AFImageResponseSerializer` | 662 | 解析 685 |
| `AFInflatedImageFromResponseWithDataAtScale()` | 568 | **强制解码**，避开首次绘制的隐式解码卡顿 |
| `+ af_safeImageWithData:` | 544 | `imageLock`（540）保护，绕开老系统上 `imageWithData:` 的线程问题 |
| `AFCompoundResponseSerializer` | 769 | 多个序列化器依次尝试 |

---

## 4. 门面 `AFHTTPSessionManager.m`

`+ manager` 50、`- initWithBaseURL:sessionConfiguration:` 66、
`GET:` 120、`HEAD:` 142、`POST:` 159 与 173（multipart）、`PUT:` 212、`PATCH:` 225、`DELETE:` 238，
六个方法共同收口于 `- dataTaskWithHTTPMethod:` **252**。
`setRequestSerializer:`（89）/ `setResponseSerializer:`（95）/ `setSecurityPolicy:`（103）都带断言校验。

## 5. 安全策略 `AFSecurityPolicy.m`

| 符号 | 行 |
|---|---|
| `- evaluateServerTrust:forDomain:` | 220（**主判定**） |
| `AFServerTrustIsValid()` | 86（系统信任链） |
| `AFPublicKeyForCertificate()` | 51（公钥模式取公钥） |
| `AFCertificateTrustChainForServerTrust()` | 100 |
| `AFPublicKeyTrustChainForServerTrust()` | 112 |
| `+ certificatesInBundle:` | 156（默认从 bundle 收 `.cer`） |
| `- setPinnedCertificates:` | 200 |

## 6. 可达性 `AFNetworkReachabilityManager.m`

`AFNetworkReachabilityStatusForFlags()` 51（flags→枚举）、`AFPostReachabilityStatusChange()` 82、
`AFNetworkReachabilityCallback()` 95、`+ sharedManager` 118、`- startMonitoring` 207（**注册回调并调度到主 RunLoop**）、`- stopMonitoring` 238。

---

## 易错点

- 回调线程只由 210/236 两行决定；序列化在 25 的并发队列，两者别混为一谈。
- manager 不 `invalidate`（700）就不会释放——`:536` 里 session 强引用了它。
- `respondsToSelector:`（898）被重写过，用它判断「是否实现了某 delegate 方法」会得到动态结果。
- 找不到 RunLoop 保活线程是正常的，见 [`../AGENTS.md`](../AGENTS.md) 的「版本纪律」。
