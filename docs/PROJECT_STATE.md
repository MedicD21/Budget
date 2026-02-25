# Project State

## Current Focus
- First launch: connect Neon DB and deploy backend to Vercel

## Completed
- Full SwiftUI iOS app (Budget, Transactions, Accounts tabs)
- Node.js Vercel serverless API (accounts, categories, budget, transactions)
- Neon Postgres schema + seed data (via GET /api/setup)
- Xcode project file (BudgetApp.xcodeproj)
- MVVM architecture: ViewModels → APIService → Vercel API → Neon DB

## Next Up
- Add NEON_DATABASE_URL to .env (get from Neon Console → Connection Details)
- Run `npm install` then `vercel dev`
- Hit GET /api/setup once to create DB tables
- Open BudgetApp.xcodeproj in Xcode, run on simulator
- Deploy backend: `vercel --prod`
- Set production API URL in APIService.swift or Xcode scheme env var
