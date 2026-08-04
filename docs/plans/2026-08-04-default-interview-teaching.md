# Default Interview Teaching Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the interview-answer style the default for all teaching requests and directly provide answers for 2–4 likely follow-up questions.

**Architecture:** The teaching index selects one default method and one default style, with an explicit opt-out for plain explanation. The interview style defines a compact answer bundle and narrowly overrides the progressive method's line, question-count, and wait-for-user constraints.

**Tech Stack:** Markdown prompt routing, shell-based content verification, Git.

---

### Task 1: Capture the current non-default baseline

**Files:**
- Verify: `prompts/teaching/INDEX.md`
- Verify: `prompts/teaching/styles/interview-answer.md`

**Step 1: Verify the style is conditional**

Run: `rg -q -F '| 按语义启用 | 面试回答与追问链 |' prompts/teaching/INDEX.md`

Expected: exit 0.

**Step 2: Verify the old interactive behavior exists**

Run: `rg -q "请用户尝试回答" prompts/teaching/styles/interview-answer.md && rg -q "3–5 个追问" prompts/teaching/styles/interview-answer.md`

Expected: exit 0.

### Task 2: Register the default style

**Files:**
- Modify: `prompts/teaching/INDEX.md`

**Step 1: Define two defaults**

Require loading the default teaching method and default expression style whenever a request enters the teaching route.

**Step 2: Add explicit opt-out behavior**

If the user asks for no interview version or only a principle explanation, load only the default method.

**Step 3: Remove semantic-only routing**

Delete the automatic interview route and change the interview style status from conditional to default.

**Step 4: Verify the index**

Run: `test "$(rg -c -F '| 默认 | 渐进式互动讲解 |' prompts/teaching/INDEX.md)" = 1 && test "$(rg -c -F '| 默认 | 面试回答与追问链 |' prompts/teaching/INDEX.md)" = 1`

Expected: exit 0.

Run: `! rg -n "自动风格路由|按语义启用" prompts/teaching/INDEX.md`

Expected: exit 0.

### Task 3: Replace interactive follow-ups with direct answers

**Files:**
- Modify: `prompts/teaching/styles/interview-answer.md`

**Step 1: Define the scoped override**

Allow the interview teaching unit to exceed 12 lines, contain 2–4 questions, and answer them immediately without an understanding-check pause. Keep all other progressive teaching constraints.

**Step 2: Define the standard output bundle**

Require one 30–60 second main answer followed by 2–4 probability-ordered follow-up questions, each with a concise spoken reference answer.

**Step 3: Remove wait-for-user behavior**

Delete instructions that ask the user to answer first and delete the one-question-at-a-time continuation flow.

**Step 4: Keep quantity stable in expanded mode**

Even when the user requests a complete answer, keep likely follow-ups between 2 and 4; only expand answer depth.

### Task 4: Verify behavior and scope

**Files:**
- Verify: `prompts/teaching/INDEX.md`
- Verify: `prompts/teaching/styles/interview-answer.md`
- Verify unchanged: `AGENTS.md`
- Verify unchanged: `CLAUDE.md`
- Verify unchanged: `prompts/teaching/methods/progressive-dialogue.md`

**Step 1: Verify required behavior**

Run: `rg -n "默认表达风格|不要面试版|2–4|直接给出|无需等待|局部覆盖" prompts/teaching`

Expected: all routing and output requirements match.

**Step 2: Verify obsolete behavior is absent**

Run: `! rg -n "按语义启用|请用户尝试回答|3–5 个追问" prompts/teaching/INDEX.md prompts/teaching/styles/interview-answer.md`

Expected: exit 0.

**Step 3: Verify untouched files**

Run: `git diff --quiet -- AGENTS.md CLAUDE.md prompts/teaching/methods/progressive-dialogue.md`

Expected: exit 0.

**Step 4: Check formatting and commit**

Run: `git diff --check`

Expected: exit 0.

```bash
git add prompts/teaching/INDEX.md prompts/teaching/styles/interview-answer.md docs/plans/2026-08-04-default-interview-teaching.md
git commit -m "docs: 默认启用面试教学输出"
```
