# Code Quality Reviewer Subagent Prompt Template

Use this template when dispatching a code quality reviewer subagent for a single wave-implementer task. Only dispatch after spec compliance review passes.

This template wraps upstream's `superpowers:requesting-code-review` reviewer methodology and adds boundary-awareness for synchronised mode.

```
Task tool (general-purpose):
  Use template at superpowers:requesting-code-review/code-reviewer.md

  DESCRIPTION: [task summary, from implementer's report]
  PLAN_OR_REQUIREMENTS: Wave N Task X from <wave-grouped plan path>
  BASE_SHA: <commit before this task's branch diverged from integration branch>
  HEAD_SHA: <implementer's final commit SHA on their branch>

  Worktree path: <worktree_path>
  Branch: <branch_name>
```

**In addition to the standard code quality concerns from `superpowers:requesting-code-review`, the reviewer should check:**

- Does each file in the diff have one clear responsibility with a well-defined interface?
- Does the implementation follow the file structure from the wave-grouped plan?
- Did this implementation create new files that are already large, or significantly grow existing files? Focus on what this change contributed, not pre-existing sizes.
- Did the implementer import correctly from contract files (rather than redefining types locally)?
- Are tests scoped to this task's worktree? Did the implementer accidentally write tests that depend on a sibling task's runtime?
- Do any comments reference the plan, a wave, a phase, a task number, or this delivery effort? Comments such as `// Wave 2: ...`, `// added in Phase A`, or `// per Task 5` are forbidden. Every comment must read as generic code documentation to a developer with no knowledge of how the change was delivered. Flag any such comment as an Important issue with the exact file:line and the corrected generic wording.

**Code reviewer returns:** Strengths, Issues (Critical/Important/Minor), Assessment.

**A boundary-violation finding is always Critical**, even if the code itself is good. The wave merge requires file-disjointness.
