# 教学提示词渐进式路由设计

## 目标

把完整互动教学协议从根 `AGENTS.md` 和 `CLAUDE.md` 中抽离，通过两级路由按需加载；当前只提供并默认使用现有的渐进式互动教学法，同时为未来增加其他方法、风格或完整预设保留扩展空间。

## 目录结构

```text
prompts/teaching/
├── INDEX.md
└── methods/
    └── progressive-dialogue.md
```

当前不创建空的 `styles/` 或 `profiles/` 目录。未来出现实际内容时再创建，并在 `INDEX.md` 注册。

## 路由规则

- 根 `AGENTS.md` 与 `CLAUDE.md` 只保留教学触发条件、索引路径及“必须按需读取”的要求。
- 当用户请求讲解、学习、原理、为什么或源码分析时，agent 首先读取 `prompts/teaching/INDEX.md`。
- `INDEX.md` 把 `methods/progressive-dialogue.md` 声明为当前默认教学法。
- agent 只读取索引选中的方法或风格文件，不扫描或一次读入整个提示词目录。
- 用户没有明确指定其他教学方式时，始终使用默认教学法。

## 默认教学法

`methods/progressive-dialogue.md` 保存当前已经验证过的完整互动教学协议，包括单轮粒度、回复长度、理解检查、停止条件和退出条件。协议内容不因本次拆分而改变。

## 扩展方式

未来新增方法时，在 `methods/` 增加文件并更新 `INDEX.md`；新增风格或完整预设时再建立 `styles/` 或 `profiles/`。根 `AGENTS.md` 和 `CLAUDE.md` 的路由入口保持稳定，不随具体提示词数量增长。

## 验证

- 根入口不再包含完整八条协议。
- 两个根入口都能指向同一个教学索引。
- 索引明确标记唯一默认教学法，并包含按需读取约束。
- 默认教学法文件完整保留原协议。
- Markdown 链接和相对路径均存在，Git 工作区无无关修改。
