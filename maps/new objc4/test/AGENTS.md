# test/ —— 模块地图

objc4 的主测试套件：260+ 个**独立可执行程序**，由 Perl 驱动，不是 XCTest。上层见 [根 AGENTS.md](../AGENTS.md)。等价指针文件 `CLAUDE.md`。

（Swift overlay 的 XCTest 是另一套，见 [ObjectiveC/AGENTS.md](../ObjectiveC/AGENTS.md)。）

## 目录：基础设施文件

| 文件 | 作用 |
|---|---|
| `test.pl` | **测试驱动**。解析源文件顶部的 `TEST_*` 指令，在 ARCH × OS × LANGUAGE × MEM × GUARDMALLOC 维度做笛卡尔积编译并运行 |
| `timeout.pl` | 单个测试的超时看门狗 |
| `test.h` | 断言与日志宏：`testassert`(94)、`testassertequal`(131)、`testassertequalstr`(137)、`testassertequalsel`(144)、`testassertnil`(151)、`succeed`(64)、`testprintf`(190)、`testwarn`(206)，以及 `TestRootAlloc` 等计数器的 extern 声明(490) |
| `testroot.i` | 提供 `TestRoot` 根类的**定义**，自动统计 alloc/dealloc/retain/release/init 次数。绝大多数测试继承它而不是 NSObject。计数器在 `test.h` 声明、这里定义，所以两个都要 include |
| `test-defines.h` | 跨测试共享的宏 |
| `defines.sh` / `defines.expected` | 校验公开头文件里导出的宏集合；改 `runtime/objc-env.h` 或公开宏时可能要同步 `defines.expected` |
| `headers.sh` | 校验公开头文件可独立编译（配合 `01-headers.c`） |
| `default-entitlements-macos.plist` / `-ios.plist` | 测试进程的默认 entitlements |
| `preopt-caches.entitlements` | 共享缓存相关测试的特殊 entitlements |

其余 `.h` 是按主题共享的测试辅助：`ARCBase.h`/`ARCMRC.h`/`MRCBase.h`/`MRCARC.h`（ARC/MRC 混合编译）、`class-structures.h`、`enumClasses.h`、`cacheflush.h`、`ivarSlide.h`、`methodListSmall.h`、`imageorder.h`、`unload.h`、`weak.h`、`future.h`、`associationForbidden.h`。

## 运行

```bash
cd test
perl test.pl                 # 全部（对系统已安装的 libobjc）
perl test.pl msgSend         # 单个，名字 = 文件名去扩展名
perl test.pl VERBOSE=2 badCache   # 打印完整输出，调试首选
perl test.pl BUILD=1 RUN=0 weak   # 只编译
perl test.pl -h              # 完整参数
```

常用参数：`ARCH=`、`OS=<sdk>[ver][-deploy[-run]]`、`ROOT=/path/to/objc4.roots`、`MEM=mrc,arc`、`LANGUAGE=c,c++,objective-c,objective-c++,swift`、`CC=`、`GUARDMALLOC=0|1|before|after`、`SANITIZE=`、`PARALLELBUILDS=N`、`BUILD_SHARED_CACHE=0|1`、`DEVICE=`、`HOST=`。

## 写测试：源文件顶部的指令

指令写在文件开头的注释块里，由 `test.pl` 正则提取：

| 指令 | 用途 |
|---|---|
| `TEST_BUILD` … `END` | 自定义编译命令。变量有 `$C{COMPILE}` / `COMPILE_C` / `COMPILE_CXX` / `COMPILE_M` / `COMPILE_MM` / `COMPILE_SWIFT` / `COMPILE_NOLINK` / `COMPILE_NOMEM` / `COMPILE_NOLINK_NOMEM`，以及 `$C{CC}`、`$C{ARCH}`、`$C{MEM}`、`$C{LANGUAGE}`、`$C{ENV}`、`$C{DSTDIR}`、`$DIR`（源目录）。全量列表：`grep -oE '\$C\{[A-Z_]+\}' test.pl \| sort -u` |
| `TEST_RUN` … `END` | 自定义运行命令 |
| `TEST_CONFIG` | 限定运行条件，如 `MEM=arc`、`ARCH=arm64`、`OS=macosx` |
| `TEST_BUILD_OUTPUT` … `END` | 用正则匹配期望的编译输出（测试编译期诊断） |
| `TEST_RUN_OUTPUT` … `END` | 用正则匹配期望的运行输出——**崩溃测试的核心机制** |
| `TEST_RUN_OUTPUT_FILTER` | 先过滤再匹配 |
| `TEST_CRASHES` | 声明本测试预期崩溃 |
| `TEST_CFLAGS` | 追加编译参数 |
| `TEST_ENV` | 设置运行时环境变量（配合 `OBJC_PRINT_*` 调试开关） |
| `TEST_ENTITLEMENTS` | 指定 entitlements plist |
| `TEST_DISABLED` | 临时禁用 |
| `TEST_NO_MALLOC_SCRIBBLE` | 关闭 malloc scribble |

**成功的测试必须在最后打印 `OK: <name>`**，由 `test.h` 的 `succeed(__FILE__)` 完成——只是退出码为 0 不算通过。

典型骨架：
```objc
// TEST_CONFIG MEM=mrc
#include "test.h"
#include "testroot.i"

int main() {
    // ... testassert(...)
    succeed(__FILE__);
}
```

## 命名规律（方便定位相关测试）

`00-`/`01-` 等数字前缀是需要最先跑的基础检查（`00-defines.c`、`01-headers.c`、`02-concurrentcat.m`、`03-load-parallel.m`、`04/05-load-image-notification*.m`、`06-ARCLayoutsWithoutWeak.m`）。其余按主题命名，直接 `ls test | grep -i <主题>` 即可：`weak*`、`arr-*`（ARC）、`association*`、`cacheflush*`、`msgSend*`、`fork*`、`synchronized*`、`bad*`（崩溃测试）、`load*`、`initialize*`、`ivar*`、`category*`、`protocol*`、`swift*`。

## 与 BATS 的关系

`objc.xcodeproj` 的 `objc4_tests` 聚合 target 用 `BUILD=1 RUN=0 BATS=1` 把测试打包进 `DSTROOT/AppleInternal/CoreOS/tests/objc4`，并生成 `objc4.plist` 供 Apple 内部 BATS 系统执行。本地开发用不到，直接跑 `test.pl` 即可。
