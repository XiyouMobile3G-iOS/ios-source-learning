# Threading/ —— 模块地图

runtime 的线程原语抽象层：锁、TLS、锁调试。所有锁与线程本地存储都必须经过这里，**不要**在 runtime 代码里直接调 pthread。上层见 [runtime/AGENTS.md](../AGENTS.md)。等价指针文件 `CLAUDE.md`。

## 目录

| 文件 | 行数 | 角色 |
|---|---|---|
| `threading.h` | 65 | **唯一入口**。定义 `tls_key` 枚举，按 `OBJC_THREADING_PACKAGE` 选择后端并组装 `objc_lock_t` 等类型 |
| `darwin.h` | 264 | Darwin 后端：`os_unfair_lock` + pthread direct TSD（`SUPPORT_DIRECT_THREAD_KEYS`） |
| `pthreads.h` | 245 | 纯 pthread 后端（可移植） |
| `c11threads.h` | 235 | C11 `<threads.h>` 后端 |
| `nothreads.h` | 144 | 单线程后端，锁全部退化为 no-op |
| `mixins.h` | 259 | 后端无关的包装：`locker_mixin`(37) 加断言/RAII，`getter_setter`(93/97/177/239) 统一 TLS 读写形式 |
| `tls.h` | 105 | TLS 宏族：`tls(T)`、`tls_fast(T)`、`tls_direct(T,K)`、`tls_direct_fast(T,K)`、`tls_autoptr(T)`、`tls_autoptr_direct(T,K)` |
| `lockdebug.h` | 146 | 调试构建下的锁序检查，被 `locker_mixin` 织入；实现在 `../objc-lockdebug.mm` |

## 后端选择

`../objc-config.h` 定义 `OBJC_THREADING_NONE/DARWIN/PTHREADS/C11THREADS`（值 0/1/2/3）与 `OBJC_THREADING_PACKAGE`，`threading.h` 据此 `#include` 对应后端头。Apple 平台走 `darwin.h`。

最终类型由 mixin 叠加而成：
```
objc_lock_t = locker_mixin<lockdebug::lock_mixin<objc_lock_base_t>>
```
后端只需提供 `objc_lock_base_t`(darwin.h:194) / `objc_recursive_lock_base_t`(darwin.h:228)，加锁语义、断言与调试由上层 mixin 统一提供。新增后端就照这两个基类实现即可。

## TLS key

`threading.h` 里的 `enum class tls_key` 是全局唯一的编号表，占用 Darwin 的 direct TSD 槽位：

| key | 用途 | 使用方 |
|---|---|---|
| `main` = 0 | `_objc_pthread_data` 主结构 | `../objc-runtime.mm` `_objc_fetch_pthread_data` |
| `sync_data` = 1 | `@synchronized` 每线程缓存 | `../objc-sync.mm` `fetch_cache` |
| `sync_count` = 2 | 同上的重入计数 | 同上 |
| `autorelease_pool` = 3 | 自动释放池页 | `../NSObject.mm` `AutoreleasePoolPage` |
| `return_autorelease_object` = 4 | 返回值自动释放优化（`SUPPORT_RETURN_AUTORELEASE`） | `../NSObject.mm` |
| `return_autorelease_address` = 5 | 同上 | 同上 |

新增 key 必须同时确认 Darwin direct TSD 槽位没有被 libpthread/libdispatch 占用——这是跨库约定，不是本仓库内部自由决定的。

## 锁的实例

runtime 的全局锁**全部声明在 `../objc-locks.h`**（不在 `objc-private.h`），形式是 `extern ExplicitInitLock<mutex_t> xxx;`，例如 `selLock`(70)、`cacheUpdateLock`(72)、`runtimeLock`(82)、`DemangleCacheLock`(83)。新增全局锁加在这里，并按文件里既定的**加锁顺序注释**排好位置——顺序即锁层级，`lockdebug` 会在调试构建下校验。

RAII 包装 `recursive_mutex_locker_t` 在 `../objc-private.h`(705)；`StripedMap`(objc-private.h:979) 用于分条加锁（SideTable、sync locks）。

fork 安全：`../NSObject.mm` 的 `SideTableLockAll`/`SideTableUnlockAll`、`../objc-sync.mm` 的 `_objc_sync_lock_atfork_child`、`../objc-initialize.mm` 的 `classInitializeAtforkPrepare/Parent/Child` 需要枚举全部锁；新增全局锁要考虑是否加入 atfork 处理。

## 相关测试

`test/synchronized.m`、`synchronized-counter.m`、`synchronized-grid.m`、`sync-error-checking.m`、`fork.m`、`forkSync.m`、`forkInitialize*.m`、`restartableRangesSynchronizeStress*.m`。
