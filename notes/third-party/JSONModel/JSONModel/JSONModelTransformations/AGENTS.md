# JSONModel 转换模块 —— 文件地图

`third-party/JSONModel/JSONModel/JSONModelTransformations/`，JSONModel **1.8.0**。行号按此 tag。

被核心模块单向调用（`JSONModel.m:723` / `:806` 调转换器，`:193` 取键映射器）。

| 文件 | 行数 | 职责 |
|---|---|---|
| `JSONValueTransformer.m` | 246 | 类型转换 |
| `JSONValueTransformer.h` | 209 | 声明全部转换方法（**当作可转换类型清单看**） |
| `JSONKeyMapper.m` | 146 | 键名映射 |
| `JSONKeyMapper.h` | 96 | |

---

## JSONValueTransformer：按方法名反射，不是查表

核心约定：要把 `A` 转成 `B`，就找方法 `-BFromA:`；导出方向找 `-JSONObjectFromB:`。
所以**扩展新类型只要写个分类加方法即可**，不需要改库。核心侧的调用点在 `JSONModel.m:723`。

| 符号 | 行 | 说明 |
|---|---|---|
| `- init` | 19 | |
| `+ classByResolvingClusterClasses:` | 34 | **把 `__NSCFString`/`__NSCFNumber` 这类类簇私有类归一**，否则类型判断全落空 |
| `- NSMutableStringFromNSString:` | 66 | 可变化系列：数组 72、字典 78 |
| `- NSSetFromNSArray:` / `- NSMutableSetFromNSArray:` | 84 / 89 | 导出方向 94 / 99 |
| `- BOOLFromNSNumber:` / `- BOOLFromNSString:` | 109 / 115 | 导出 125 |
| `- floatFromObject:` / `FromNSString:` / `FromNSNumber:` | 131 / 136 / 141 | 导出 146 |
| `- NSNumberFromNSString:` / `- NSStringFromNSNumber:` | 152 / 157 | |
| `- NSDecimalNumberFromNSString:` | 162 | 导出 167 |
| `- NSURLFromNSString:` | 173 | 导出 180 |
| `- importDateFormatter` | 186 | **共享的 `NSDateFormatter`**，ISO8601 格式假设 |
| `- __NSDateFromNSString:` | 198 | 导出 204；另有 `- NSDateFromNSNumber:` 217（时间戳） |
| `- NSTimeZoneFromNSString:` | 224 | 导出 228 |
| `- __NSDictionaryFromNSArray:` | 234 | 可变版 240 |

---

## JSONKeyMapper：键名映射

| 符号 | 行 | 说明 |
|---|---|---|
| `- initWithJSONToModelBlock:modelToJSONBlock:` | 10 | 最底层 |
| `- initWithModelToJSONBlock:` | 15 | |
| `- initWithDictionary:` | 25 | |
| `- initWithModelToJSONDictionary:` | 32 | **最常用**：显式字典映射 |
| `- JSONToModelKeyBlock` | 45 | |
| `+ swapKeysAndValuesInDictionary:` | 50 | 反向表 |
| `- convertValue:isImportingToModel:` | 58 | **实际转换点**（核心在导入时调它） |
| `+ mapperFromUnderscoreCaseToCamelCase` | 68 | 下划线→驼峰（别名 `+mapperForSnakeCase` 73） |
| `+ mapperForTitleCase` | 109 | |
| `+ mapperFromUpperCaseToLowerCase` | 117 | |
| `+ mapper:withExceptions:` | 125 | 基础映射 + 例外表 |
| `+ baseMapper:withModelToJSONExceptions:` | 132 | |

模型侧通过重写 `+keyMapper`（`../JSONModel/JSONModel.h:234`）声明；
全局映射 `+setGlobalKeyMapper:`（`JSONModel.h:124`）**已标记废弃**，新代码别用。

---

## 易错点

- `importDateFormatter`（`:186`）是共享实例，格式固定；后端返回别的日期格式时要自己写 `-NSDateFromNSString:` 分类覆盖。
- 转换全靠方法名拼接，**方法名写错不会编译报错，只会静默不转换**——排查「某字段一直是 nil」先确认方法名。
- 类簇问题（`:34`）是这个库最隐蔽的一处：`[obj class]` 拿到的常是私有子类，直接和 `NSString` 比会不相等。
