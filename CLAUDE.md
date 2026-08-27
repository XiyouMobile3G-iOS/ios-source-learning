# CLAUDE.md

本目录的完整项目说明在同目录的 [`AGENTS.md`](./AGENTS.md)，请按需读取。

## 工作区未搭建时

本仓库不含任何源码本体。先跑 `./bootstrap.sh --check`（只体检、不改动，会逐个报告本地有没有、
版本对不对），缺源码时**先告知用户**再运行 `./bootstrap.sh`（首次约 2–3 GB）：

- Apple 底层六份：`new objc4/` `CF-1153.18-apple/` `libdispatch-apple/` `libdispatch/`
  `swift-corelibs-foundation/` `swift-foundation/`
- 参照实现一份：`gnustep-base/`（**非 Apple 代码**，补 Apple 从未开源的 Foundation ObjC 实现，
  主要是 `NSNotificationCenter` 与 KVO；约 12 MB，可单独补：`./bootstrap.sh gnustep`）
- 第三方库三份，都在 `third-party/` 下：`AFNetworking/` `JSONModel/` `SDWebImage/`（合计约 70 MB，
  可单独补：`./bootstrap.sh afnetworking jsonmodel sdwebimage`）

源码由 `.gitignore` 忽略、不进本仓库，脚本每轮会复核这一点。
版本与地图基准不符时脚本只提示不自动切换，**转达提示即可，不要自行 checkout**。
细则见 `AGENTS.md` 的「规范零」，脚本完整用法见 `README.md` 的「脚本使用说明」。

## 教学提示词渐进式路由

当用户请求「讲解」「学习」「原理」「为什么」或源码分析时：

1. 必须先读取并遵循 [`prompts/teaching/INDEX.md`](./prompts/teaching/INDEX.md)。
2. 用户未指定其他已注册方法或风格时，使用索引声明的默认教学方法。
3. 只读取索引为本次讲解选中的提示词文件，不要扫描或一次性读入整个提示词目录。
