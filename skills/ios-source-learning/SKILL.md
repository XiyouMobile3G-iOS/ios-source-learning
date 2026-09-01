---
name: ios-source-learning
description: Answer source-backed iOS and Objective-C internals questions using the ios-source-learning workspace's version-pinned source maps. Use for Objective-C runtime, RunLoop/CoreFoundation, GCD, Foundation, NotificationCenter, KVO, AFNetworking, JSONModel, YYModel, and SDWebImage; not for general API usage questions that do not need implementation evidence.
---

# iOS Source Learning

Use the `ios-source-learning` repository as a navigation layer over real source code. Its
`AGENTS.md`, `maps/`, and `sources.sh` are authoritative; this skill deliberately does
not duplicate their versioned maps.

## Find the workspace

1. If the current directory or an ancestor contains `AGENTS.md`, `maps/`, and `sources.sh`,
   use that repository root.
2. Otherwise, ask the user for a prepared checkout or clone
   `https://github.com/XiyouMobile3G-iOS/ios-source-learning.git`. Do not silently download
   the tracked source trees: the first full bootstrap is 2-3 GB. State that cost and wait for
   approval before running `./bootstrap.sh`.
3. Read the root `AGENTS.md` before examining any implementation. It contains the current
   repository routing, version policy, evidence boundaries, and bootstrap requirements.

## Answer from source

For a source-level question, first select the narrowest target in the root routing table and
read its mapped `AGENTS.md`. Use the resulting symbol and line references to inspect only the
needed source range. Do not browse entire source directories or substitute blog posts for
implementation evidence.

Before making a current-source claim, run `./check-updates.sh <target>` from the workspace:

- `0`: read the local pinned source.
- `10`: run `./update-sources.sh <target>`, then read the source.
- `2`: retry the same check once with the required network permission. If it still fails,
  state that the answer is based on the local version. Do not bypass the script with manual
  `git fetch`, `git pull`, or `git ls-remote`.

Cite the source as `file:line` and name the applicable tag, drop, or commit. Keep evidence
types distinct: Apple source is not interchangeable with Swift open-source implementations or
the GNUstep reference implementation. In particular, label GNUstep conclusions as GNUstep,
not as Apple's implementation.

## Teach at the right pace

For learning, explanation, or "why" requests, follow the teaching prompt selected by
`prompts/teaching/INDEX.md` after the version and map-routing steps above. Unless the user asks
for a complete walkthrough, introduce one smallest prerequisite concept at a time and end with
one focused comprehension check.

For a direct question or a requested complete explanation, give the conclusion first, then the
minimal source-backed reasoning and citations.
