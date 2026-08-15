# AFNetworking —— 模块索引

`AFNetworking/AFNetworking`，钉在 **tag `4.0.1`**（本地分支同名 `4.0.1`）。所有子文档的行号都按 4.0.1 写。

**本文件只做路由与跨模块串联，不放符号表。**按下表选中一个模块再读那一份。

---

## 按任务定位

| 问题涉及 | 去读 |
|---|---|
| `NSURLSession` 封装、task↔delegate 映射、`resume`/`suspend` swizzle、回调线程 | [`AFNetworking/AGENTS.md`](./AFNetworking/AGENTS.md) |
| 请求参数编码、URL 转义、multipart 上传 | 同上（请求序列化一节） |
| 响应解析、状态码/MIME 校验、图片强制解码 | 同上（响应序列化一节） |
| HTTPS 证书与公钥锁定（SSL Pinning） | 同上（安全策略一节） |
| 网络可达性监听 | 同上（可达性一节） |
| `GET`/`POST` 等业务门面 | 同上（门面一节） |
| 图片下载器、内存图片缓存、`UIImageView`/`UIButton` 分类、状态栏菊花 | [`UIKit+AFNetworking/AGENTS.md`](./UIKit+AFNetworking/AGENTS.md) |
| 某个行为的边界到底是什么（超时、重定向、编码细节） | [`Tests/AGENTS.md`](./Tests/AGENTS.md) |

`Framework/AFNetworking.h`（66 行）只是 framework target 的伞头文件，`Example/`、`fastlane/` 与源码研究无关，都不必读。

---

## 模块划分

| 目录 | 行数 | 角色 |
|---|---|---|
| `AFNetworking/` | 约 4500 | **核心**：6 个文件构成完整的请求链路 |
| `UIKit+AFNetworking/` | 约 2100 | UI 层分类，依赖核心，反过来不依赖 |
| `Tests/Tests/` | 23 个用例文件 | 行为边界的实测依据 |

---

## 跨模块：一次请求的完整链路

模块内部细节各看各的文档，**这条链是跨模块的，只在这里记**：

1. `AFHTTPSessionManager.m:120` `GET:` → `:252` `dataTaskWithHTTPMethod:`（门面）
2. `AFURLRequestSerialization.m:475` `requestBySerializingRequest:` 造 request（请求序列化）
3. `AFURLSessionManager.m:732` `dataTaskWithRequest:` → `:596` `addDelegateForDataTask:` 建立 task→delegate 映射
4. 系统回调进 `AFURLSessionManagerTaskDelegate`（`:90`）→ `:173` `didCompleteWithError:`
5. 在 `:25` 的并发队列上做响应序列化 → `AFURLResponseSerialization.m:110` 校验 + 解析
6. `AFURLSessionManager.m:210`/`:236` `dispatch_group_async` 派发回 `completionQueue ?: 主队列`

图片走另一条：`UIImageView+AFNetworking.m:73` → `AFImageDownloader.m:203` →（合并同 URL 请求）→ 复用上面的核心链路。

## 跨模块：通知这条暗线

核心层用 swizzle 给每个 task 的 `resume`/`suspend` 发通知（`AFURLSessionManager.m:343-435`），
UI 层的菊花管理器（`AFNetworkActivityIndicatorManager.m:142`/`:148`）**只订阅这些通知**，两个模块之间没有直接调用。
排查「菊花不转」或「计数不归零」时，要同时看这两处。

---

## 版本纪律

- 本仓库钉在 `4.0.1`，`update-sources.sh` 对它只 fetch 报告、不切换版本；不要自行 `git checkout` 升版。
- **4.x 与 2.x 是两套实现**：4.x 已删除 `NSURLConnection`、`AFHTTPRequestOperation` 和那条常驻 RunLoop 线程。
  网上关于「AFN 用 `[NSRunLoop currentRunLoop] run]` 保活线程」的结论只适用于 2.x，**在本 drop 里找不到对应代码**。
- 引用写成 `AFURLSessionManager.m:210`（AFNetworking 4.0.1）。
