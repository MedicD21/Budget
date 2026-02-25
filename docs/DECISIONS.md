# Architecture Decisions

## 2026-02-25 — Cents-based money storage
- Context: Floating point arithmetic causes rounding errors in financial apps
- Decision: Store all monetary values as integers (cents) in DB and in-memory
- Reasoning: $1.00 = 100, eliminates float precision issues entirely
- Tradeoffs: Division by 100 needed for display; handled by formatCurrency() helper

## 2026-02-25 — No auth for v1
- Context: Single-user app to start; auth adds significant complexity
- Decision: No authentication in v1; single shared database
- Reasoning: Get to working product faster; auth can be layered on later
- Tradeoffs: Not suitable for multi-user or public deployment without auth

## 2026-02-25 — Computed account balance (not stored)
- Context: Storing a balance field requires updating it on every transaction
- Decision: Compute balance dynamically as starting_balance + SUM(transactions)
- Reasoning: Always accurate; eliminates sync issues; simple to reason about
- Tradeoffs: Slightly slower reads at large transaction volumes

## 2026-02-25 — Simple ready-to-assign model (no rollover)
- Context: YNAB has complex monthly rollover logic
- Decision: readyToAssign = totalInflow (ever) - totalAllocated (ever)
- Reasoning: Simpler to implement correctly in v1; sufficient for single-user
- Tradeoffs: Does not carry overspending forward month-to-month; add in v2

## 2026-02-25 — Vercel serverless + Neon Postgres
- Context: Need low-cost, scalable backend for iOS app
- Decision: Vercel Functions for API, Neon for Postgres
- Reasoning: Free tier sufficient; serverless = no cold infrastructure
- Tradeoffs: Cold start latency on first request; 15s function timeout limit
