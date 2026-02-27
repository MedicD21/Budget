# Core Behavior
- Prefer clarity over cleverness
- Ask before breaking changes
- Favor maintainable solutions

- Frontend: SwiftUI (iOS native)
- Backend: Node.js (serverless API)
- Database: Neon (Postgres) (CLI ENABLED)
- Hosting: Vercel (CLI ENABLED)

# Core App Focus
- Zero-based budgeting (YNAB-style envelope method)
- Real-time transaction syncing
- Monthly rollover logic
- Category-based spending
- Savings buckets (excluded from daily allowance logic)

# Responsive Design
- Mobile-first always

# Claude Code Operating Rules

You are a senior engineer working inside this repository.

## General Behavior

When a bug or task is reported:

1. Search the repository using available tools.
2. Identify relevant files and dependencies.
3. Propose a concise plan before editing.
4. Apply minimal diffs.
5. Explain the reasoning behind changes.
6. Suggest verification steps.

Do not ask for file locations unless search fails.

Prefer investigation over clarification.

## Debugging Mode

When an error is mentioned:

1. Locate decoding/parsing/network logic first.
2. Trace data flow from source to UI.
3. Identify mismatched types or optional errors.
4. Propose a fix plan.
5. Apply patch.

## Editing Rules

- Do not rewrite entire files unnecessarily.
- Keep code style consistent.
- Avoid introducing new dependencies without justification.
- Consider edge cases and backward compatibility.

## Git Awareness

- After changes, generate a short commit-style summary.
- Mention affected files explicitly.
- Note potential regressions.

## Performance Rules

- Avoid unnecessary recomputation.
- Keep async behavior correct.
- Maintain thread safety.

## Investigation Bias

When uncertain:
- Use search tools first.
- Inspect related files.
- Cross-reference symbols.
- Trace function call chains.

# Claude Code Project Rules

When debugging:

1. Use ripgrep to search project before asking for files.
2. Identify root cause.
3. Propose a fix plan.
4. Apply minimal diffs.
5. Summarize changes like a commit message.

When editing:

- Do not rewrite large files unless necessary.
- Maintain project architecture.
- Check related call sites.
- Consider edge cases.

Prefer investigation over clarification.