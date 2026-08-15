# JSONModel 核心模块 —— 文件地图

`third-party/JSONModel/JSONModel/JSONModel/`，JSONModel **1.8.0**。行号按此 tag。

| 文件 | 行数 | 职责 |
|---|---|---|
| `JSONModel.m` | 1387 | 内省 + 导入校验 + 类型分派 + 导出 |
| `JSONModel.h` | 284 | 公开 API 与四个标记协议 |
| `JSONModelClassProperty.{h,m}` | 48 / 53 | 单个属性的元信息载体 |
| `JSONModelError.{h,m}` | 103 / 82 | 错误类型与 keyPath 拼接 |

跨模块链路见 [`../../AGENTS.md`](../../AGENTS.md)；类型转换与键映射在 [`../JSONModelTransformations/AGENTS.md`](../JSONModelTransformations/AGENTS.md)。

---

## 一、属性内省（每个类只做一次）

`JSONModel.m:530` `__inspectProperties` 是整个库的核心：

| 位置 | 做什么 |
|---|---|
| `:541` | `while (class != [JSONModel class])` 沿继承链上溯，**只收集到 JSONModel 为止** |
| `:546` | `class_copyPropertyList` 取属性列表 |
| `:561` | `property_getAttributes` 取类型编码，用 `NSScanner` 解析 |
| `:584` | 类型名含 `Mutable` → `p.isMutable` |
| `:587-611` | **扫属性上的协议名**：`Optional`(594) / `Index`(596) / `Ignore`(608)；其余视为集合元素类名存入 `p.protocol`(611) |
| `:648` / `:652` | 再问 `+propertyIsOptional:` / `+propertyIsIgnored:`（第二条声明途径） |
| `:658` | `+classForCollectionProperty:` 的结果也写进 `p.protocol` |
| `:671-679` | 探测自定义存取器：`set<Name>With<Type>:` 与 `JSONObjectFor<Name>` |

结果缓存在**类对象**上：`:85` `objc_setAssociatedObject(self.class, &kClassPropertiesKey, ...)`，
入口判断 `:78`（在 `:75` `__setup__` 内）。关联对象 key 定义在 `:19-22`，全局状态在 `:25-31`。

`+load`（`:41`）用 `dispatch_once` 初始化两张白名单：
`allowedJSONTypes`（`:49`，9 种 JSON 类）与 `allowedPrimitiveTypes`（`:54`，基本类型及 `NSInteger` 等别名）。

`JSONModelClassProperty.h` 的字段清单（19-46）：
`name` / `type` / `structName` / `protocol` / `isOptional` / `isStandardJSONType` / `isMutable` / `customGetter` / `customSetters`。

---

## 二、导入与校验

| 符号 | 行 | 说明 |
|---|---|---|
| `- initWithDictionary:error:` | 151 | **总入口**；`:161` 非字典报错、`:170` 模型无效报错 |
| `- initWithData:error:` | 104 | `:118` JSON 坏了报 `errorBadJSON` |
| `- initWithString:error:` / `usingEncoding:` | 128 / 136 | |
| `- __keyMapper` | 193 | 从关联对象取（设置在 `:84`） |
| `- __doesDictionary:matchModelWithKeyMapper:error:` | 199 | **必填校验**；`:220` 按 keyPath 取值；`:244` 报缺键 |
| `- __requiredPropertyNames` | 492 | `:500` 非 Optional 即必填 |
| `- __importDictionary:withKeyMapper:validation:error:` | 272 | **最长一段**，下面分支都在其中 |
| 取值 | 284 | `valueForKeyPath:` 支持 `a.b.c` |
| 空值分支 | 290-298 | 非 Optional 且缺失 → 报错；Optional → `continue` |
| 自定义 setter | 329-341 | 有就用，没有走 `setValue:forKey:` |
| 嵌套模型 | 361-376 | 值是字典 + 属性是 JSONModel 子类 → 递归 init |
| 集合分支 | 384-420 | 用 `property.protocol` 逐元素建模；`:404` `isMutable` 决定回填可变容器 |
| 标准 JSON 类型 | 401-410 | 类型直接匹配就赋值 |
| `- __isJSONModelSubClass:` | 481 | |
| `- __transform:forProperty:error:` | 723 | 类型不匹配时找转换器 |
| `- __customSetValue:forProperty:` | 841 | |

---

## 三、导出

| 符号 | 行 |
|---|---|
| `- toDictionary` | 899 |
| `- toJSONString` / `- toJSONData` | 904 / 909 |
| `- toDictionaryWithKeys:` | 915（**真正干活的一份**） |
| `- toJSONDataWithKeys:` / `- toJSONStringWithKeys:` | 1030 / 1049 |
| `- __reverseTransform:forProperty:` | 806 |
| `- __customGetValue:forProperty:` | 861 |
| `- __createDictionariesForKeyPath:inDictionary:` | 876（按 keyPath 建嵌套字典） |
| `+ arrayOfModelsFromDictionaries:` | 1057（带 error 的版本 1076） |
| `+ arrayOfModelsFromData:` / `FromString:` | 1062 / 1070 |
| `+ dictionaryOfModelsFrom...` | 1115 / 1120 / 1128 |
| `+ arrayOfDictionariesFromModels:` | 1161（带导出字段过滤 1180） |

---

## 四、标记协议与错误

`JSONModel.h`：`ConvertOnDemand` 22、`Index` 26、`Ignore` 37、`Optional` 47，
`NSObject (JSONModelPropertyCompatibility)` 53（**声明 NSObject 符合它们，纯为消警告**），
`JSONModel` 声明 120，`+keyMapper` 234、`+propertyIsOptional:` 243、`+propertyIsIgnored:` 252、`+classForCollectionProperty:` 274。

`JSONModelError.m`：`errorInvalidDataWithMessage:` 15、`WithMissingKeys:` 23、`WithTypeMismatch:` 30、
`errorBadResponse` 37、`errorBadJSON` 44、`errorModelIsInvalid` 51、`errorInputIsNil` 58、
**`errorByPrependingKeyPathComponent:` 65**（把嵌套层级拼进 keyPath，排查嵌套模型报错先看它）。

---

## 易错点

- `Optional` / `Ignore` **是空协议标记**，靠 `:587-611` 扫类型编码里的协议名生效，不是真的实现协议。
- 集合元素类型必须用 `<ElementClass>` 写法或 `+classForCollectionProperty:` 声明，否则数组里留的还是原始字典。
- 内省停在 `JSONModel` 这一层（`:541`），**JSONModel 自身的属性不参与映射**。
- 内省结果挂在类对象上，**运行时动态改类结构（如 `class_addProperty`）不会重新内省**。
- `:220` / `:284` 用的是 `valueForKeyPath:`，键名里带点号会被当成路径分隔符。
