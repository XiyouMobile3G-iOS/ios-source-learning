# runtime/ —— 模块地图

libobjc 的全部实现。上层背景见 [根 AGENTS.md](../AGENTS.md)；子模块见 [Messengers.subproj](./Messengers.subproj/AGENTS.md)（汇编 msgSend）与 [Threading](./Threading/AGENTS.md)（锁/TLS 抽象）。等价指针文件 `CLAUDE.md`。

符号名对应 objc4-951.7，定位用 `grep -n '<符号>' runtime/*.mm` 即可；行号会随 drop 漂移，优先按符号找。

## 按任务定位（先看这张表）

| 我要改/查的东西 | 去哪个文件 | 入口符号 |
|---|---|---|
| 类的实现结构、category、ivar 布局 | `objc-runtime-new.mm/.h` | `realizeClassWithoutSwift`、`methodizeClass`、`attachCategories` |
| isa 位域、nonpointer isa | `isa.h` | `ISA_BITFIELD`、`ISA_MASK`、`ISA_MAGIC_VALUE` |
| retain/release/weak 快路径 | `objc-object.h` | `rootRetain`、`rootRelease`、`rootAutorelease` |
| NSObject 本体、自动释放池、SideTable | `NSObject.mm` + `NSObject-internal.h` | `AutoreleasePoolPage`、`SideTables()` |
| 方法缓存 | `objc-cache.mm` + `objc-runtime-new.h` | `cache_t`、`bucket_t`、`cache_hash` |
| `objc_msgSend` 本身 | `Messengers.subproj/objc-msg-*.s` | 见该目录 AGENTS.md |
| 弱引用表 | `objc-weak.mm/.h` | `weak_register_no_lock`、`weak_clear_no_lock` |
| 关联对象 | `objc-references.mm` | `_object_set_associative_reference` |
| `@synchronized` | `objc-sync.mm` | `id2data`、`objc_sync_enter` |
| `+initialize` | `objc-initialize.mm` | `initializeNonMetaClass`、`callInitialize` |
| `+load` | `objc-loadmethod.mm` | `call_load_methods`、`add_class_to_loadable_list` |
| 异常 | `objc-exception.mm` | `objc_exception_throw`、`__objc_personality_v0` |
| 镜像加载 / dyld 回调 | `objc-os.mm` + `objc-runtime-new.mm` | `map_images_nolock`、`load_images`、`_objcInit` |
| 环境变量、runtime 初始化 | `objc-runtime.mm` + `objc-env.h` | `environ_init`、`_objcInit` |
| Mach-O section 读取 | `objc-file.mm` + `objc-opt.mm` | `header_info::classlist` 等一族 |
| 属性存取器 | `objc-accessors.mm` | `objc_getProperty`、`reallySetProperty` |
| SEL 注册 | `objc-sel.mm` + `objc-sel-table.s` | `sel_registerName`、`__sel_registerName` |
| 类型编码解析 | `objc-typeencoding.mm` | `encoding_getArgumentInfo` |
| imp_implementationWithBlock | `objc-block-trampolines.mm` + `objc-blocktramps-*.s` | `imp_implementationWithBlock` |
| 崩溃/日志/fault | `objc-errors.mm` | `_objc_fatal`、`_objc_inform`、`_objc_fault` |
| runtime 内部分配器 | `objc-zalloc.h/.mm` | `Zone<T>`、`zalloc`、`zfree` |
| ivar GC layout 位图 | `objc-layout.mm` | `layout_bitmap_create`、`compress_layout` |
| 编译期特性开关 | `objc-config.h` | `SUPPORT_*` 宏 |
| 全局锁的声明与加锁顺序 | `objc-locks.h` | `runtimeLock`、`selLock`、`cacheUpdateLock` |
| 旧式哈希表/映射表（遗留 API） | `hashtable2.mm`、`maptable.mm` | `NXHashTable`、`NXMapTable` |
| `Object`/`Protocol` 遗留类 | `Object.mm`、`Protocol.mm`、`OldClasses.subproj/List.h` | — |

## 分层：三类头文件

改动新增 API 时，三层的可见性要一起确认。

- **公开 API**：`objc.h`、`runtime.h`、`message.h`、`NSObject.h`、`objc-api.h`、`NSObjCRuntime.h`、`Protocol.h`、`objc-exception.h`、`objc-sync.h`、`objc-auto.h`
- **SPI（Apple 内部/调试可见）**：`objc-internal.h`（1.5k 行，最大的 SPI 面）、`objc-abi.h`（编译器约定的 ABI 符号）、`objc-gdb.h`（调试器读取 runtime 结构的契约，改数据结构必须同步）、`NSObject-private.h`、`objc-probes.d`（DTrace）
- **纯内部**：`objc-private.h`（总入口，含 `objc_object`、`StripedMap`、`DisguisedPtr`、`ChainedHookFunction`、`SmallVector`、`header_info`）、`objc-runtime-new.h`、`objc-object.h`、`objc-os.h`、`isa.h`、`NSObject-internal.h`
- **Swift 可见性**：`Module/ObjectiveC.modulemap` + `.apinotes`（公开）、`ModulePrivate/ObjectiveC_Private.modulemap` + `.apinotes`（SPI）

## objc-runtime-new.h：核心数据结构地图

这是理解 runtime 的必读文件，按结构分块：

- `bucket_t`(214) / `preopt_cache_t`(310) / `cache_t`(337) —— 方法缓存；`cache_t` 内嵌到 `objc_class`，与汇编共享布局
- `entsize_list_tt`(696) —— 所有列表的基类模板；`method_list_t`(1241)、`ivar_list_t`(1496)、`property_list_t`(1502) 都由它派生
- `method_t`(914) —— 支持 big/small（相对指针）两种形式，`remappedImp`/`remapImp` 处理 small method 的 IMP 重映射
- `ivar_t`(1205) / `property_t`(1227) / `protocol_t`(1516) / `protocol_list_t`(1568)
- `relative_list_list_t`(1380) —— 新版 category 预附加列表
- `class_ro_t`(1598) —— 编译期只读部分
- `list_array_tt`(1685) 及 `method_array_t`(2168) / `property_array_t`(2183) / `protocol_array_t`(2193)
- `class_rw_ext_t`(2202) / `class_rw_t`(2212) —— 运行期可写部分，`extAlloc` 惰性分配 ext
- `class_data_bits_t`(2364) —— `objc_class::bits`，低位标志 + 指向 ro/rw 的指针
- `objc_class`(2635) / `swift_class_t`(3178) / `category_t`(3196) / `stub_class_t`(673)

## objc-runtime-new.mm 关键流程（~10k 行，按流程读）

1. **镜像映射**：`map_images_nolock`(objc-os.mm) → `_read_images` → `readClass` / `realizeAllClassesInImage`
2. **类实现化**：`realizeClassMaybeSwiftAndUnlock` → `realizeClassWithoutSwift`(2961) → `methodizeClass`(1734)；Swift 类走 `realizeSwiftClass`(3182) / `_objc_realizeClassFromSwift`(3140)
3. **ivar 布局**：`reconcileInstanceVariables`(2843) → `moveIvars`(2798)（非脆弱 ivar 的核心）
4. **category 附加**：`load_categories_nolock`(3585) → `loadAllCategoriesIfNeeded`(3719) → `attachCategories`
5. **类查找表**：`getClassFromNamedClassTable`(2098)、`addNamedClass`(2152)、`futureNamedClasses`(2203)、`remapClass`(2347)
6. **继承树**：`addSubclass`(2629) / `removeSubclass`(2675) / `addRootClass`(2596)；遍历用 `foreach_realized_class_and_subclass`(826)
7. **缓存刷新**：`flushCaches`(3466) / `_objc_flush_caches`(3492)
8. **卸载**：`unmap_image`(3785)

Swift 名字改写（`copySwiftV1MangledName`(1973) / `copySwiftV1DemangledName`(1926)）也在本文件。

## NSObject.mm 分区

- 顶部：`_objc_setBadAllocHandler`、Swift 引用计数桥接（`_initializeSwiftRefcounting`）
- `SideTables()`(203) + `StripedMap<SideTable>` —— 溢出引用计数与弱引用表宿主；`SideTableLockAll` 用于 fork 安全
- weak API 区：`storeWeak`(365)、`objc_storeWeak`、`objc_initWeak`、`objc_loadWeakRetained`(563)、`objc_copyWeak`、`objc_destroyWeak`；后台压缩线程 `weakTableScan`(292)
- ARC 入口：`objc_storeStrong`(269)、`objc_retainBlock`、`objc_retain_autorelease`
- 下半部分：`AutoreleasePoolPage`（定义在 `NSObject-internal.h` 的 `AutoreleasePoolPageData`(133) + `magic_t`(94)）、`objc_autoreleasePoolPush/Pop`
- 最后：`NSObject` 类本身的方法实现

真正的 retain/release 快路径不在这里，在 `objc-object.h`（`rootRetain` / `rootRelease` / `rootTryRetain` / `sidetable_*`）。

## 约定

- 实现文件是 `.mm`（Objective-C++），但内部不用 ObjC 对象、不用 ARC，用 C++ 写。
- 断言用 `ASSERT()`（`objc-private.h`），不用 `assert()`；致命错误用 `_objc_fatal()`。
- 所有锁 / TLS / 原子操作走 `Threading/` 抽象层，不直接调 pthread。
- 加调试开关：在 `objc-env.h` 加一行 `OPTION(...)`，可能需要同步 `test/defines.expected`。
- 改 `cache_t` / `objc_class` / `method_t` 布局：必须同步 `Messengers.subproj/objc-msg-*.s` 和 `objc-gdb.h`。
