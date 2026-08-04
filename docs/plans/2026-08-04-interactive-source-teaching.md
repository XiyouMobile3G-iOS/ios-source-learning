# Interactive Source Teaching Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make source explanations default to short, genuinely interactive teaching turns in both Codex and Claude.

**Architecture:** Keep `AGENTS.md` as the complete project instruction source for Codex. Duplicate only the mandatory interactive teaching protocol into the automatically loaded root `CLAUDE.md`, which continues to point to `AGENTS.md` for the remaining project documentation.

**Tech Stack:** Markdown project instructions, shell-based content verification, Git.

---

### Task 1: Replace the ambiguous Codex teaching rule

**Files:**
- Modify: `AGENTS.md:32-42`

**Step 1: Verify the new protocol is absent**

Run: `rg -n "强制互动教学协议|用户回答前" AGENTS.md`

Expected: no matches.

**Step 2: Add the minimal protocol**

Replace the current “对话式讲解” section with rules that define triggers, one minimal concept per turn, a 12-line prose limit, one comprehension question, an immediate stop, and explicit opt-out phrases.

**Step 3: Verify the protocol is present**

Run: `rg -n "强制互动教学协议|首轮禁止|用户回答前|一次讲完" AGENTS.md`

Expected: all four rules match.

### Task 2: Make the protocol visible to Claude

**Files:**
- Modify: `CLAUDE.md:1-3`

**Step 1: Verify the root Claude entry is only a pointer**

Run: `wc -l CLAUDE.md`

Expected: three lines.

**Step 2: Add the same mandatory teaching protocol**

Keep the pointer to `AGENTS.md`, but include the full interactive teaching rules so Claude does not depend on following a Markdown link.

**Step 3: Compare both protocols**

Run: `rg -n "首轮禁止|正文不超过|理解检查|用户回答前|退出互动教学模式" AGENTS.md CLAUDE.md`

Expected: every rule appears in both files.

### Task 3: Verify scope and record the change

**Files:**
- Verify: `AGENTS.md`
- Verify: `CLAUDE.md`
- Verify: `docs/plans/2026-08-04-interactive-source-teaching.md`

**Step 1: Inspect the final diff**

Run: `git diff --check && git diff -- AGENTS.md CLAUDE.md docs/plans/2026-08-04-interactive-source-teaching.md`

Expected: no whitespace errors; only the approved prompt and plan changes appear.

**Step 2: Commit**

```bash
git add AGENTS.md CLAUDE.md docs/plans/2026-08-04-interactive-source-teaching.md
git commit -m "docs: 强制源码讲解采用互动教学"
```
