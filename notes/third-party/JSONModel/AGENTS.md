# JSONModel —— 模块索引

`jsonmodel/jsonmodel`，钉在 **tag `1.8.0`**（本地分支同名 `1.8.0`）。所有子文档的行号都按 1.8.0 写。

**本文件只做路由与跨模块串联，不放符号表。**

全库仅 3350 行，是这个工作区里体量最小的一份，**价值在于它是 objc runtime 属性内省的教科书样本**——
配合 `../../new objc4/runtime/` 的类型编码与关联对象实现一起读收益最大。

---

## 按任务定位

| 问题涉及 | 去读 |
|---|---|
| 属性内省、`Optional`/`Ignore` 怎么生效、必填校验、导入导出主流程 | [`JSONModel/JSONModel/AGENTS.md`](./JSONModel/JSONModel/AGENTS.md) |
| 类型转换（`NSString`→`NSDate` 等）、键名映射（下划线↔驼峰） | [`JSONModel/JSONModelTransformations/AGENTS.md`](./JSONModel/JSONModelTransformations/AGENTS.md) |
| `JSONHTTPClient` / `JSONAPI` / `initFromURLWithString:` | [`JSONModel/JSONModelNetworking/AGENTS.md`](./JSONModel/JSONModelNetworking/AGENTS.md)（**已废弃，别当重点**） |
| 三个模块的目录关系与伞头文件 | [`JSONModel/AGENTS.md`](./JSONModel/AGENTS.md) |

`Examples/` 与四个平台 target 目录（`JSONModel-mac` / `-tvOS` / `-watchOS`）只有工程配置，不必读。

---

## 模块划分

| 目录 | 行数 | 角色 |
|---|---|---|
| `JSONModel/JSONModel/` | 约 1900 | **核心**：内省 + 导入 + 导出 + 错误 |
| `JSONModel/JSONModelTransformations/` | 约 700 | 类型转换与键映射，被核心调用 |
| `JSONModel/JSONModelNetworking/` | 约 600 | 历史包袱，与核心无本质关联 |

---

## 跨模块：一次 `initWithDictionary:` 的完整链路

模块内细节各看各的，**这条链跨模块，只在这里记**：

1. `JSONModel.m:151` `initWithDictionary:error:` 入口
2. `:75` `__setup__` → `:78` 查关联对象，**没内省过才做一次** `:530` `__inspectProperties`
3. `:193` `__keyMapper` 取键映射器 → 转换交给 `JSONKeyMapper.m:58` `convertValue:isImportingToModel:`
4. `:199` `__doesDictionary:matchModelWithKeyMapper:error:` 做**必填校验**，缺键在 `:244` 报错
5. `:272` `__importDictionary:...` 逐属性赋值；类型对不上时走 `:723` `__transform:forProperty:`
6. `__transform:` 按方法名约定去 `JSONValueTransformer` 找转换方法（该模块文档有约定说明）

导出是反向的一条：`:899` `toDictionary` → `:915` `toDictionaryWithKeys:` → `:806` `__reverseTransform:`。

## 跨模块：与 objc4 的对照点

- `JSONModel.m:546` `class_copyPropertyList` / `:561` `property_getAttributes` —— 类型编码格式见 objc4 的 runtime 文档
- `JSONModel.m:85` `objc_setAssociatedObject` 把内省结果挂在**类对象**上 —— 实现在 `../../new objc4/runtime/objc-references.mm`
- `:587-611` 从类型编码里抠协议名，是「空协议当标记用」这一手法的完整示范

---

## 版本纪律

- 钉在 `1.8.0`，`update-sources.sh` 只 fetch 报告，不切换版本。
- 引用写成 `JSONModel.m:530`（JSONModel 1.8.0）。
