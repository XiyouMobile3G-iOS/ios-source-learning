# Progressive Teaching Prompt Routing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move the complete interactive teaching protocol out of root agent files and load it progressively through a stable teaching prompt index.

**Architecture:** `AGENTS.md` and `CLAUDE.md` keep only trigger and routing instructions. `prompts/teaching/INDEX.md` selects the current default method, while `prompts/teaching/methods/progressive-dialogue.md` owns the complete protocol.

**Tech Stack:** Markdown project instructions, shell-based path/content verification, Git.

---

### Task 1: Create the teaching prompt library

**Files:**
- Create: `prompts/teaching/INDEX.md`
- Create: `prompts/teaching/methods/progressive-dialogue.md`

**Step 1: Verify the routes do not exist**

Run: `test ! -e prompts/teaching/INDEX.md && test ! -e prompts/teaching/methods/progressive-dialogue.md`

Expected: exit 0.

**Step 2: Create the index**

The index must declare `methods/progressive-dialogue.md` as the default, require loading only the selected prompt, define fallback behavior for unknown selections, and document future `methods/`, `styles/`, and `profiles/` registration without creating empty directories.

**Step 3: Move the complete protocol into the default method**

Copy the current eight rules and minimal-subconcept definition from `AGENTS.md` without changing their behavior.

**Step 4: Verify the library**

Run: `rg -n "默认|按需读取|progressive-dialogue|首轮禁止|用户回答前" prompts/teaching`

Expected: the index contains routing terms and the method contains the complete protocol.

### Task 2: Reduce the root agent instructions to routes

**Files:**
- Modify: `AGENTS.md:32-45`
- Modify: `CLAUDE.md:3-18`

**Step 1: Replace the full Codex protocol**

Keep the five teaching triggers and require reading `prompts/teaching/INDEX.md`. State that the default selection applies unless the user explicitly requests another registered method or style, and prohibit scanning all prompt files.

**Step 2: Replace the full Claude protocol**

Use the same short route in `CLAUDE.md` so both automatically loaded entry points converge on one index.

**Step 3: Verify progressive disclosure**

Run: `rg -n "prompts/teaching/INDEX.md|只读取索引选中的" AGENTS.md CLAUDE.md`

Expected: both roots contain the same route.

Run: `! rg -n "首轮禁止|正文不超过|理解检查问题|用户回答前" AGENTS.md CLAUDE.md`

Expected: exit 0 because implementation details have left the root files.

### Task 3: Verify paths, content, and scope

**Files:**
- Verify: `AGENTS.md`
- Verify: `CLAUDE.md`
- Verify: `prompts/teaching/INDEX.md`
- Verify: `prompts/teaching/methods/progressive-dialogue.md`

**Step 1: Check every Markdown route target**

Run: `test -f prompts/teaching/INDEX.md && test -f prompts/teaching/methods/progressive-dialogue.md`

Expected: exit 0.

**Step 2: Check formatting and final diff**

Run: `git diff --check && git diff -- AGENTS.md CLAUDE.md prompts/teaching docs/plans/2026-08-04-progressive-teaching-prompt-routing.md`

Expected: no whitespace errors and no unrelated changes.

**Step 3: Commit**

```bash
git add AGENTS.md CLAUDE.md prompts/teaching docs/plans/2026-08-04-progressive-teaching-prompt-routing.md
git commit -m "docs: 渐进加载教学提示词"
```
