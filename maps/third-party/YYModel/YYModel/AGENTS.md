# YYModel 核心模块 —— 文件地图

`third-party/YYModel/YYModel/`，YYModel **1.0.4**，行号按 commit `50250b0` 对应的 tag 写。

| 文件 | 行数 | 职责 |
|---|---:|---|
| `YYClassInfo.m` | 362 | runtime 类、method、ivar、property 元数据与缓存 |
| `YYClassInfo.h` | 200 | 元数据类型与公开查询接口 |
| `NSObject+YYModel.m` | 1840 | 元数据组合、JSON 映射、导入导出与辅助 API |
| `NSObject+YYModel.h` | 430 | model 协议、转换钩子与公开分类 API |
| `YYModel.h` | 22 | 伞头文件 |

## 一、runtime 元数据

| 符号 | 位置 | 作用 |
|---|---|---|
| `-[YYClassPropertyInfo initWithProperty:]` | `YYClassInfo.m:153` | 解析属性 type encoding、类名和协议名 |
| `-[YYClassInfo initWithClass:]` | `YYClassInfo.m:257` | 建立类/元类关系并首次更新元数据 |
| `-[YYClassInfo _update]` | `YYClassInfo.m:273` | 枚举 method、property、ivar 列表 |
| `+[YYClassInfo classInfoWithClass:]` | `YYClassInfo.m:329` | 用 `dispatch_once` + semaphore 保护元数据缓存 |

## 二、model 元数据组合

| 符号 | 位置 | 作用 |
|---|---|---|
| `+metaWithClassInfo:propertyInfo:generic:` | `NSObject+YYModel.m:348` | 把 runtime 属性信息转成映射元数据 |
| `-_YYModelMeta initWithClass:` | `NSObject+YYModel.m:478` | 处理黑/白名单、容器泛型、key mapper 与属性表 |
| `+metaWithClass:` | `NSObject+YYModel.m:628` | 缓存每个 model class 的 `_YYModelMeta` |
| `ModelSetValueForProperty` | `NSObject+YYModel.m:784` | 按属性类型分派数字、Foundation 类型、容器和嵌套模型 |

`modelCustomPropertyMapper` 在 `:549-603` 处理普通 key、key path 和多 key 映射；
`modelContainerPropertyGenericClass` 在 `:501-521` 解析容器元素类。

## 三、导入与导出

| 符号 | 位置 | 说明 |
|---|---|---|
| `+yy_modelWithJSON:` / `+yy_modelWithDictionary:` | `NSObject+YYModel.m:1453-1469` | JSON 解码后创建 model |
| `-yy_modelSetWithJSON:` / `-yy_modelSetWithDictionary:` | `NSObject+YYModel.m:1473-1483` | 把字典写入已有实例 |
| `-yy_modelToJSONObject` | `NSObject+YYModel.m:1524` | model 转 Foundation JSON 对象 |
| `-yy_modelToJSONData` / `-yy_modelToJSONString` | `NSObject+YYModel.m:1538-1548` | 序列化为 data/string |
| `+yy_modelArrayWithClass:json:` | `NSObject+YYModel.m:1777` | 批量字典转 model 数组 |
| `+yy_modelDictionaryWithClass:json:` | `NSObject+YYModel.m:1811` | 批量字典转 model 字典 |

嵌套 model、数组/字典/集合泛型转换集中在 `:894-1031`；自定义转换钩子和导出路径见
`modelCustomWillTransformFromDictionary:`、`modelCustomTransformFromDictionary:` 和
`modelCustomTransformToDictionary:` 的调用点 `:1200-1388`。

## 易错点

- `YYClassInfo` 的元数据缓存和 `_YYModelMeta` 的 model 缓存是两层，不要混为一个缓存。
- 容器元素类型来自 `modelContainerPropertyGenericClass` 或属性协议名；没有泛型类时不会递归创建元素 model。
- `modelCustomPropertyMapper` 支持 key path 和多个候选 key，读取时要同时看 `:549-603` 与导入分支。
