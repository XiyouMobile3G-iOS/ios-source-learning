# 贡献指南

## 提交方式

`main` 受分支保护。请从 `main` 创建一个描述清楚的分支，提交改动并发起 Pull Request；不要直接向 `main` 推送。

Pull Request 至少需要一名审查者批准，并通过仓库要求的自动检查后才能合并。涉及源码地图、版本清单或脚本行为的改动，请同时更新相关说明并运行对应测试。

## Skill

`skills/ios-source-learning/` 是可安装的 Codex Skill。它只封装工作流规则，不复制 `maps/` 或上游源码；版本、地图和证据边界始终以根目录 `AGENTS.md`、`maps/` 与 `sources.sh` 为准。
