# SDWebImage 源码根目录 —— 模块路由

`third-party/SDWebImage/SDWebImage/`，SDWebImage **5.21.7**。本目录是主 target 的源码根，**只做路由**。

| 子目录 | 内容 | 文档 |
|---|---|---|
| `Core/` | 全部核心实现，60+ 文件、约 15000 行（.m） | [`Core/AGENTS.md`](./Core/AGENTS.md) |
| `Private/` | 内部工具与动图播放引擎，约 2400 行 | [`Private/AGENTS.md`](./Private/AGENTS.md) |
| `include/SDWebImage/` | **头文件副本，不是另一份实现** | 不必读 |
| `Resources/` | PrivacyInfo 等资源 | 不必读 |

跨模块链路与底层咬合点在库根索引 [`../AGENTS.md`](../AGENTS.md)。

---

## 头文件副本陷阱

`include/SDWebImage/` 下每个 `.h` 都与 `Core/` 下同名文件**内容完全相同**，
是为 framework/SPM 的头文件搜索路径准备的。后果：

- `grep -rn "SDWebImageManager" SDWebImage/` 的结果会成对出现，看着像有两套实现
- **引用行号一律写 `Core/`**，不要写 `include/`
- 想减少噪音：`grep -rn "符号" SDWebImage/Core SDWebImage/Private`

## Core 与 Private 的边界

`Core/` 是公开 API 面，`Private/` 是不进 umbrella header 的实现细节。
两处容易找错：

- 动图**播放**（帧调度、时钟）在 `Private/`（`SDDisplayLink`、`SDImageFramePool`），
  动图**解码与容器**在 `Core/`（`SDAnimatedImage`、`SDImageIOAnimatedCoder`）
- 多缓存串联的 operation 在 `Private/SDImageCachesManagerOperation.m`，而门面 `SDImageCachesManager` 在 `Core/`
