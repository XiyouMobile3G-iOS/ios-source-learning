# YYModel —— 模块索引

`ibireme/YYModel`，钉在 **tag `1.0.4`**（commit `50250b0`）。所有子文档的行号都按此 tag 写。

**本文件只做路由与跨模块串联，不放符号表。** YYModel 是一个独立于 JSONModel 的 Objective-C
模型映射库，核心价值在于把 runtime 的类/属性元数据缓存与 JSON 映射结合起来。

## 按任务定位

| 问题涉及 | 去读 |
|---|---|
| 类、ivar、method、property 元数据与缓存 | [`YYModel/AGENTS.md#一runtime-元数据`](./YYModel/AGENTS.md#一runtime-元数据) |
| JSON ↔ model 映射、容器泛型、键路径、自定义转换 | [`YYModel/AGENTS.md#二model-元数据组合`](./YYModel/AGENTS.md#二model-元数据组合) / [`YYModel/AGENTS.md#三导入与导出`](./YYModel/AGENTS.md#三导入与导出) |
| 边界行为与类型转换回归用例 | [`YYModelTests/AGENTS.md`](./YYModelTests/AGENTS.md) |
| 公开 API、协议与安装方式 | `YYModel/YYModel.h`、`YYModel/NSObject+YYModel.h` |

## 模块划分

| 目录 | 行数 | 角色 |
|---|---:|---|
| `YYModel/` | 约 2,900 | 核心：runtime 元数据、映射、导入导出、归档与集合辅助 |
| `YYModelTests/` | 约 1,800 | XCTest：类型转换、映射、嵌套模型、黑白名单与归档 |

## 跨模块链路

一次 `yy_modelWithDictionary:` 的主要路径：

1. `NSObject+YYModel.m:1458` 创建 model，并在 `:1463` 取得 `_YYModelMeta`。
2. `_YYModelMeta` 在 `:478-625` 组合 `YYClassInfo`、属性元数据、泛型类和自定义 key mapper。
3. `:1478` 进入字典导入，容器与嵌套 model 分支集中在 `:894-1031`。
4. 导出从 `:1524` 开始，数组/字典批量转换在 `:1777-1840`。

`YYClassInfo` 使用 `class_copyPropertyList`、`class_copyMethodList`、`class_copyIvarList`，
与 `new objc4/runtime/` 的属性、方法和类布局地图配套阅读。

## 版本纪律

- 钉在 `1.0.4`；`update-sources.sh` 只 fetch 和报告，不自动切换版本。
- 引用写成 `NSObject+YYModel.m:1458`（YYModel 1.0.4）。
- 源码目录由 `bootstrap.sh` 下载并被 `.gitignore` 忽略；地图正文只放在本目录及子目录的 `AGENTS.md`。
