# dyld —— Mach-O 装载与 fixups 源码地图

Apple `apple-oss-distributions/dyld`，基准 tag **`dyld-1378`**（commit `fd8d0c4d52320ebf64db34f3cb280310d905c5ae`）。

研究的是该 tag 的 dyld 4 源码，**不得**由源码 tag 直接推出任意发行版 iOS 的实际行为；设备行为须再以 Mach-O 检查和真机 trace 验证。源码树包含运行期 dyld、Mach-O 解析/写入工具、shared cache builder；查启动 fixups 时优先 `dyld/` 与 `mach_o/`。

## 按任务定位

| 问题 | 去哪个文件 | 关键符号 / 行号 |
|---|---|---|
| 启动阶段何时统一应用 fixups | `dyld/dyldMain.cpp` | `dyld4::prepare` 的 fixup loop `:770-798`；dyld 自身先 rebase `rebaseSelf` `:1260-1269` |
| 如何按 Loader 类型分派 fixups | `dyld/Loader.cpp` | `Loader::applyFixups` `:367-382` |
| 磁盘镜像的即时绑定与写回 | `dyld/JustInTimeLoader.cpp` | `JustInTimeLoader::applyFixups` `:774-898`；先解析目标表 `:806-850`，再 `applyFixupsGeneric` `:854-855` |
| rebase / bind 在运行期分别写什么 | `dyld/JustInTimeLoader.cpp` | `logFixup` `:628-669`；rebase 是 image + runtime offset，bind 是 target loader / symbol |
| 预构建 Loader / closure 的运行时路径 | `dyld/PrebuiltLoader.cpp`、`.h` | shared-cache Loader 无普通 fixups `PrebuiltLoader.cpp:486-498`；预计算 bind target 表后调用通用 fixups `:501-567`；磁盘位置在 `PrebuiltLoader.h:53-56` |
| 旧式 rebase opcode | `mach_o/RebaseOpcodes.cpp`、`.h` | 解析 `RebaseOpcodes::forEachRebase` `:108-197`；枚举位置 `:199-223` |
| 旧式 bind / lazy bind / weak bind opcode | `mach_o/BindOpcodes.cpp`、`.h` | opcode 解释 `BindOpcodes::forEachBind` `:157-275`；位置 / target 枚举 `:277-314`；lazy / weak 分支 `:424-440` |
| 怎样判断 Mach-O 使用旧式还是 chained fixups | `mach_o/Image.cpp`、`UnsafeHeader.cpp` | load command 解析 `Image.cpp:339-390`；两种格式不可共存 `:407-413`；`hasOpcodeFixups` / `hasChainedFixups` `UnsafeHeader.cpp:2849-2866` |
| chained-fixups 的磁盘结构和按页入口 | `include/mach-o/fixup-chains.h`、`mach_o/ChainedFixups.cpp` | header/imports `fixup-chains.h:36-46`；每 segment 的 page start 表 `:57-68`；遍历非空页面和 chain start `ChainedFixups.cpp:158-190` |
| chained fixups 对 iOS 版本的链接策略 | `mach_o/Policy.cpp` | iOS 从 13.4 起可用 `:142-169`；arm64e 新格式从 iOS 15.0 起 `:174-204` |
| shared cache 本身的 slide / 修复 | `dyld/SharedCacheRuntime.cpp` | 将 `__DATA_CONST` 设可写、再 `fixupDataPages(slide)` `:957-979` |
| fixups 的性能 trace 事件 | `dyld/Tracing.h`、`dyld/dyldMain.cpp` | `DBG_DYLD_TIMING_APPLY_FIXUPS` `Tracing.h:66-70`；启动路径计时 `dyldMain.cpp:773-798` |

## 证据边界与易错点

- `RebaseOpcodes` / `BindOpcodes` 是 **旧式 `LC_DYLD_INFO[_ONLY]`** 的两张表；`LC_DYLD_CHAINED_FIXUPS` 是另一种格式。`Image.cpp:407-413` 明确拒绝一个 Mach-O 同时携带两者。
- chained fixups 并不是“没有 bind”；它的 import table 仍存 `libOrdinal`、`symbolName`、addend、weak-import 信息（`ChainedFixups.cpp:93-144`），每个链节点再编码 rebase 或 bind。
- “按页”是链的定位组织方式：`page_start[]` 指出每一页的首链节点，`DYLD_CHAINED_PTR_START_NONE` 表示该页没有 fixup（`fixup-chains.h:57-77`）。这支持减少扫描无 fixup 页，**不等价于**证明每次启动没有 page fault。
- shared-cache image 走 `PrebuiltLoader` 且位于 cache 时会跳过普通 fixup；非 cache 的 app / embedded framework 仍会进入 `applyFixupsGeneric`。不要把 shared-cache 优化泛化为全部 app 镜像。
- `DYLD_PRINT_BINDINGS` 只在允许环境变量的安全条件下启用（`DyldProcessConfig.cpp:1024-1026`）；App Store/真机实验不可将它当成稳定可用的观察手段。
