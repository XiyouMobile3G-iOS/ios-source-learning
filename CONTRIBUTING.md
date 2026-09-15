# 贡献指南

## 提交方式

`main` 受分支保护。请从 `main` 创建描述清楚的分支，提交改动并发起 Pull Request；不要直接向 `main` 推送。

Pull Request 至少需要一名审查者批准，并通过仓库要求的自动检查后才能合并。涉及源码地图、版本清单或脚本行为的改动，请同时更新相关说明并运行对应测试。

## 开始前

```bash
git clone https://github.com/XiyouMobile3G-iOS/ios-source-learning.git
cd ios-source-learning
./bootstrap.sh --check
```

源码本体不在本仓库中，由 `bootstrap.sh` 从 `sources.sh` 声明的上游仓库下载；全量首次准备约 2–3 GB。只研究一个目标时，使用 `./bootstrap.sh <target>`，不要在未告知下载规模的情况下执行全量 bootstrap。

源码目录属于独立的只读上游仓库，已由 `.gitignore` 忽略；不要把源码本体或源码目录中的临时文件提交到本仓库。

## 源码地图贡献

地图正文位于 `maps/` 下对应目录的 `AGENTS.md`。源码树中同路径的 `AGENTS.md` / `CLAUDE.md` 由 `bootstrap.sh` 挂载，不要直接在源码目录创建新的未跟踪地图文件。

地图应包含：

- 文件和目录清单；
- 关键函数、结构体、宏或跨文件入口及精确行号；
- 对应的 tag、drop 或 commit；
- 能帮助 agent 少读文件的版本陷阱和权威性边界。

地图不应包含：

- 教程正文、个人心得或推导；
- 大段复制的源码；
- 不带源码版本的行号和实现结论。

单份地图通常控制在 200 行内。新增或修改地图后，从仓库根目录运行：

```bash
./bootstrap.sh --maps-only
```

如果源码版本发生变化，必须同时校对受影响的所有行号、版本说明和跨模块链接；不要只修改 `sources.sh` 而保留旧地图。

## 新增或升级源码

新增上游源码只修改 `sources.sh` 的 `SOURCES` 清单，并确认新目录已加入 `.gitignore`；不要在 `bootstrap.sh`、`check-updates.sh`、`update-sources.sh` 中重复维护清单。

升级 pinned 源码时，必须在同一个 PR 中提交新的 ref、地图行号和相关文档。提交前先运行 `./check-updates.sh <target>`，遵循脚本给出的版本策略，不要用手工 `git checkout` 绕过保护。

## 教学提示词和 Skill

教学方法放在 `prompts/teaching/methods/`，表达风格放在 `prompts/teaching/styles/`，新增文件后必须在 `prompts/teaching/INDEX.md` 注册。只有实际存在内容时才创建新的方法、风格或预设目录。

Codex Skill 位于 `skills/ios-source-learning/`；它只封装工作流，不复制地图、版本清单或上游源码。其他 agent 入口也必须继续以根目录 `AGENTS.md`、`maps/` 和 `sources.sh` 为事实来源。

## 本地验证

提交前至少运行：

```bash
bash -n bootstrap.sh check-updates.sh update-sources.sh progress.sh tests/*.sh
./tests/progress.test.sh
./tests/track-ref.test.sh
./tests/check-updates-status.test.sh
```

修改地图、提示词路由或 Markdown 链接时，还应运行对应的完整性检查，并在 PR 描述中列出实际执行的命令和结果。

## Pull Request 要求

PR 标题沿用仓库已有的 Conventional Commits 风格，例如 `docs:`、`test:`、`fix:` 或 `feat:`。正文请说明：

1. 修改的目标、模块和源码版本；
2. 是否改变地图行号、版本策略或 agent 路由；
3. 运行过的验证命令及结果；
4. 尚未覆盖的边界或需要维护者确认的取舍。

小而单一的 PR 更容易审查。若改动依赖另一个未合并的 PR，请在正文中明确链接，避免重复实现。
