# CLAUDE.md

本目录的完整项目说明在同目录的 [`AGENTS.md`](./AGENTS.md)，请按需读取。

## 工作区未搭建时

本仓库不含 Apple 源码本体。若 `new objc4/` `CF-1153.18-apple/` `libdispatch-apple/`
`libdispatch/` `swift-corelibs-foundation/` 这五个目录不存在，先告知用户，再运行
`./bootstrap.sh`（首次约 2–3 GB）。细则见 `AGENTS.md` 的「规范零」。

## 教学提示词渐进式路由

当用户请求「讲解」「学习」「原理」「为什么」或源码分析时：

1. 必须先读取并遵循 [`prompts/teaching/INDEX.md`](./prompts/teaching/INDEX.md)。
2. 用户未指定其他已注册方法或风格时，使用索引声明的默认教学方法。
3. 只读取索引为本次讲解选中的提示词文件，不要扫描或一次性读入整个提示词目录。
