# JSONModel 源码根目录 —— 模块路由

`third-party/JSONModel/JSONModel/`，JSONModel **1.8.0**。本目录是三个模块的父目录，**只做路由**。

| 子目录 / 文件 | 行数 | 内容 | 文档 |
|---|---|---|---|
| `JSONModel/` | 约 1900 | 核心：内省、导入校验、导出、错误 | [`JSONModel/AGENTS.md`](./JSONModel/AGENTS.md) |
| `JSONModelTransformations/` | 约 700 | 类型转换 + 键名映射 | [`JSONModelTransformations/AGENTS.md`](./JSONModelTransformations/AGENTS.md) |
| `JSONModelNetworking/` | 约 600 | 网络便捷层，**已废弃** | [`JSONModelNetworking/AGENTS.md`](./JSONModelNetworking/AGENTS.md) |
| `JSONModelLib.h` | 19 | 伞头文件，只有一串 `#import`，读它没有信息量 |

跨模块链路与 objc4 对照点在库根索引 [`../AGENTS.md`](../AGENTS.md)。

## 依赖方向

核心 → 转换（单向）。核心在 `JSONModel.m:27` 持一个全局 `JSONValueTransformer`，
在 `:723` `__transform:` / `:806` `__reverseTransform:` 里调用它。
网络层依赖核心，核心不依赖网络层——**删掉 `JSONModelNetworking/` 不影响任何映射功能**。
