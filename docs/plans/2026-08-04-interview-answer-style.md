# Interview Answer Style Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a semantically triggered interview-answer style that composes with the default progressive teaching method and trains one likely follow-up at a time.

**Architecture:** The teaching index detects interview intent and selects `styles/interview-answer.md` in addition to the default method. The method continues to control pacing; the style controls spoken-answer structure, follow-up hooks, and interview-specific quality constraints.

**Tech Stack:** Markdown prompt routing, shell-based content verification, Git.

---

### Task 1: Establish the missing-style baseline

**Files:**
- Verify: `prompts/teaching/INDEX.md`
- Verify absence: `prompts/teaching/styles/interview-answer.md`

**Step 1: Verify the style is absent**

Run: `test ! -e prompts/teaching/styles/interview-answer.md`

Expected: exit 0.

**Step 2: Verify the index has no interview route**

Run: `! rg -n "面试|interview-answer" prompts/teaching/INDEX.md`

Expected: exit 0.

### Task 2: Create the interview-answer style

**Files:**
- Create: `prompts/teaching/styles/interview-answer.md`

**Step 1: Define composition behavior**

State that the default method owns turn length and stopping rules, while this style owns answer presentation and follow-up selection.

**Step 2: Define the normal turn format**

Require a 30–60 second spoken answer using conclusion, mechanism, and boundary; include one accurate follow-up hook; expose only one likely follow-up; use that follow-up as the single comprehension question and wait for the user.

**Step 3: Define continuation and one-shot behavior**

After the user answers, correct it and provide an improved spoken answer before advancing. If the user explicitly requests a complete answer, output a prioritized main-answer/follow-up/reference-answer chain.

**Step 4: Define safety and quality constraints**

Forbid fabricated experience, invented measurements, inaccurate hooks, textbook prose, and exhaustive question dumping in progressive mode.

### Task 3: Register semantic routing

**Files:**
- Modify: `prompts/teaching/INDEX.md`

**Step 1: Add method/style composition order**

Specify that methods control teaching cadence, styles control presentation, and selected methods are loaded before selected styles.

**Step 2: Add a semantic route**

Route interview-related intent—such as asking how to answer an interviewer or requesting likely follow-ups—to `styles/interview-answer.md`. Clarify that examples describe semantics rather than exact keyword matching.

**Step 3: Register the available style**

Add a style table with the interview-answer style as conditional, not default.

### Task 4: Verify behavior and scope

**Files:**
- Verify: `prompts/teaching/INDEX.md`
- Verify: `prompts/teaching/styles/interview-answer.md`
- Verify unchanged: `AGENTS.md`
- Verify unchanged: `CLAUDE.md`

**Step 1: Verify routing and style content**

Run: `rg -n "语义|面试|interview-answer|30–60|一个.*追问|等待用户|一次讲完" prompts/teaching`

Expected: index contains semantic routing and the style contains all output constraints.

**Step 2: Verify default behavior remains unchanged**

Run: `test "$(rg -c -F '| 默认 |' prompts/teaching/INDEX.md)" = 1`

Expected: exactly one default method row.

**Step 3: Verify root entries are untouched**

Run: `git diff --quiet -- AGENTS.md CLAUDE.md`

Expected: exit 0.

**Step 4: Check formatting and commit**

Run: `git diff --check`

Expected: exit 0.

```bash
git add prompts/teaching/INDEX.md prompts/teaching/styles/interview-answer.md docs/plans/2026-08-04-interview-answer-style.md
git commit -m "docs: 添加面试回答与追问链风格"
```
