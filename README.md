# Budget

A YNAB-style zero-based budgeting app. iOS native (SwiftUI) + Vercel serverless API + Neon Postgres.

## Tech Stack
- Frontend: SwiftUI (iOS 17+)
- Backend: Node.js Vercel Serverless Functions
- Database: Neon Postgres (via @neondatabase/serverless)
- Hosting: Vercel

## Setup

### 1. Backend
```bash
npm install
# Add NEON_DATABASE_URL to .env (get from Neon Console → Connection Details)
vercel dev
# Then open http://localhost:3000/api/setup once to create DB tables
```

### 2. iOS App
```
open BudgetApp/BudgetApp.xcodeproj
# In Xcode: Edit Scheme → Run → Arguments → Environment Variables
# Add API_BASE_URL = http://localhost:3000 for local dev
# Build & run on simulator
```

### 3. Deploy
```bash
vercel --prod
# Update API_BASE_URL in Xcode scheme to your production URL
```

## API Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | /api/setup | Create DB tables (run once) |
| GET/POST | /api/accounts | List / create accounts |
| PUT/DELETE | /api/accounts/:id | Update / delete account |
| GET/POST | /api/category-groups | List / create groups |
| GET/POST | /api/categories | List / create categories |
| GET | /api/budget/:year/:month | Full budget for a month |
| PUT | /api/budget/:year/:month/allocate | Assign money to category |
| GET/POST | /api/transactions | List / create transactions |
| PUT/DELETE | /api/transactions/:id | Update / delete transaction |

## Project Docs
- AGENTS.md — AI behavior & rules
- docs/PROJECT_STATE.md — current status
- docs/DECISIONS.md — architecture choices
- docs/CHANGELOG.md — change history
