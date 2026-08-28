# SDWebImage MapKit 模块 —— 文件地图

`third-party/SDWebImage/SDWebImageMapKit/MapKit/`，SDWebImage **5.21.7**。

独立子库（单独的 podspec / target），只有一个分类，241 行：

| 文件 | 行数 | 内容 |
|---|---|---|
| `MKAnnotationView+WebCache.h` | 170 | API 声明与文档注释 |
| `MKAnnotationView+WebCache.m` | 71 | 实现：**全部转调 `UIView+WebCache`** |

---

## 要点

实现只做三件事：把 `MKAnnotationView.image` 作为设置目标、指定 operation key、
调用 `Core/UIView+WebCache.m:58` 的 `sd_internalSetImageWithURL:...`。
**没有任何独立的缓存或下载逻辑**——所有行为都与 `UIImageView` 一致，问题排查直接去
[`../../SDWebImage/Core/AGENTS.md`](../../SDWebImage/Core/AGENTS.md) 的「UI 分类」一节。

因为是独立 target，`SDWebImageMapKit/include/` 同样存在头文件副本，与主库一个套路。

## 唯一值得注意的差异

地图标注视图会被 MapKit 频繁复用（类似 cell 复用），**错图问题比 `UIImageView` 更常见**；
取消机制仍是 `Core/UIView+WebCacheOperation.m:54` 的按 key 取消。
