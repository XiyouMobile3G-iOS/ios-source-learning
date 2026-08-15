# JSONModel 网络模块 —— 文件地图（已废弃）

`third-party/JSONModel/JSONModel/JSONModelNetworking/`，JSONModel **1.8.0**。

> **先说结论**：这是历史包袱。它自己拼 `NSMutableURLRequest`、用早期的同步/回调式网络封装，
> 实际项目里这一层由 AFNetworking 承担（见 [`../../../AFNetworking/AGENTS.md`](../../../AFNetworking/AGENTS.md)）。
> **研究 JSONModel 的映射机制时不要顺着这里展开**，它与核心机制没有本质关联。

| 文件 | 行数 | 内容 |
|---|---|---|
| `JSONHTTPClient.m` | 361 | 简易 HTTP 客户端 |
| `JSONAPI.m` | 145 | 单例式 API 门面 + JSON-RPC |
| `JSONModel+networking.m` | 101 | 给 JSONModel 加的网络便捷分类 |

---

## 符号定位

| 符号 | 位置 | 说明 |
|---|---|---|
| 默认配置 | `JSONHTTPClient.m:26-39` | 编码 UTF-8、`ReloadIgnoringLocalCacheData`、超时 60s、全局 `requestHeaders` |
| `+ requestDataFromURL:method:requestBody:headers:handler:` | 同上 `:132` | **真正发请求的一份** |
| `+ requestDataFromURL:method:params:headers:handler:` | 同上 `:211` | 参数版 |
| `+ JSONFromURLWithString:...` | 同上 `:247` / `:257` / `:267` | 三个重载 |
| `+ getJSONFromURLWithString:` / `+ postJSONFromURLWithString:` | 同上 `:314` / `:332` | 便捷入口 |
| `+ urlEncode:` | 同上 `:107` | 自带的编码实现 |
| `+ setAPIBaseURLWithString:` | `JSONAPI.m:46` | 全局 baseURL |
| `+ getWithPath:andParams:completion:` | 同上 `:57` | POST 版 67 |
| `+ __rpcRequestWithObject:completion:` | 同上 `:77` | JSON-RPC，`rpcWithMethodName:` 114、`rpc2WithMethodName:` 127 |
| `JSONAPIRPCErrorModel` | 同上 `:144` | RPC 错误模型 |
| `- initFromURLWithString:completion:` | `JSONModel+networking.m:28` | 拉取并直接建模 |
| `+ getModelFromURLWithString:` / `+ postModel:toURLWithString:` | 同上 `:56` / `:78` | |
| `- isLoading` | 同上 `:18` | 用关联对象存状态（setter 23） |

---

## 如果一定要读

看点只有一个：`JSONModel+networking.m:28` 展示了「网络响应 → `initWithDictionary:` → 模型」的拼接方式，
而这正是实际项目里改用 AFN 后需要自己写的那一小段胶水。核心链路见 [`../../AGENTS.md`](../../AGENTS.md)。
