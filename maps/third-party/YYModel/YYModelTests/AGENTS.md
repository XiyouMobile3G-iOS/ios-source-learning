# YYModel 测试模块 —— 用例定位

`third-party/YYModel/YYModelTests/`，YYModel **1.0.4**。测试是 XCTest，不参与源码地图的实现路径。

| 文件 | 行数 | 覆盖行为 |
|---|---:|---|
| `YYTestClassInfo.m` | 191 | C/Objective-C 类型编码、属性/方法/ivar 元数据 |
| `YYTestModelMapper.m` | 293 | 自动/自定义 key mapper、key path、多 key 和容器泛型 |
| `YYTestAutoTypeConvert.m` | 456 | 数字、字符串、日期、URL、容器等自动转换 |
| `YYTestNestModel.m` | 58 | 嵌套 model 与集合中的嵌套 model |
| `YYTestCustomTransform.m` | 96 | model 自定义导入/导出转换 |
| `YYTestBlacklistWhitelist.m` | 105 | 属性黑名单、白名单 |
| `YYTestCopyingAndCoding.m` | 185 | NSCopying、NSCoding 与归档 |
| `YYTestModelToJSON.m` | 169 | model 到 JSON 对象、data、string |

高频入口：

- `YYTestClassInfo.m:18-56` 声明覆盖多种 ObjC 属性编码的测试 model。
- `YYTestModelMapper.m:24-44` 展示普通 key、key path、同 key 多属性和多候选 key。
- `YYTestModelMapper.m:72-83` 展示 NSArray/NSDictionary/NSSet 的协议泛型声明。
- `YYTestNestModel.m` 覆盖字典、数组和字典容器中的递归建模。

测试源码按 `1.0.4` 引用；当前工作区只维护定位地图，不在此处执行 Xcode 构建。
