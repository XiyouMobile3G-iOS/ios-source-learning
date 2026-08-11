# Network Permission Retry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让 agent 在源码更新检查因沙箱网络限制失败时，申请网络权限后统一重跑检查脚本。

**Architecture:** 只修改根目录 `AGENTS.md` 的更新流程和退出码表。保留 `check-updates.sh` 与 `update-sources.sh` 的职责边界，不引入手动 Git 更新路径。

**Tech Stack:** Markdown、Bash 命令约定

---

### Task 1: 补充网络权限重试规则

**Files:**
- Modify: `AGENTS.md:26-37`

**Step 1: 修改更新检查流程**

在 `check-updates.sh` 的退出码处理规则中写明：退出码 `2` 时，申请网络权限并原样重跑一次；若仍为 `2`，才声明基于本地版本。

**Step 2: 写明禁止绕过脚本**

明确网络失败时不得改用手动 `git fetch`、`git pull` 或 `git ls-remote` 更新源码。

**Step 3: 验证规则文本**

Run: `rg -n '网络权限|重跑一次|仍返回|git fetch|git pull|git ls-remote' AGENTS.md`

Expected: 所有重试条件和禁止绕过约束均能匹配。

**Step 4: 检查变更范围**

Run: `git diff --check && git diff -- AGENTS.md`

Expected: 无空白错误，且只包含预期的流程文档变更。
