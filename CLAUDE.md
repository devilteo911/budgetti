# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
flutter pub get                              # Install dependencies
flutter pub run build_runner build           # Generate Drift ORM code (required after schema changes)
flutter run                                  # Run on connected device/emulator
flutter analyze                              # Lint
flutter test                                 # Run tests
flutter build apk / ios / web               # Production builds
flutter pub run flutter_native_splash:create # Regenerate splash screen
```

After modifying `lib/core/database/database.dart`, always regenerate with `build_runner build` to update `database.g.dart`.

## Architecture

**Flutter app (Dart)** using feature-driven modular architecture:

- **State management**: Riverpod (`flutter_riverpod`) — all providers defined in `lib/core/providers/providers.dart`
- **Routing**: GoRouter with `StatefulShellRoute` for bottom navigation — configured in `lib/core/router/app_router.dart`
- **Database**: Drift ORM over SQLite for local persistence — schema in `lib/core/database/database.dart`, generated code in `database.g.dart`
- **Backend**: PocketBase for auth and cloud sync (`PocketBaseSyncService`; auth via `AuthService` + `AsyncAuthStore`)
- **Theme**: Material Design 3 dark theme — `lib/core/theme/app_theme.dart` (mint green primary #63E6BE, pure black background)

### Data flow

```
Drift SQLite + Supabase (data layer)
  → Services (lib/core/services/) — business logic
    → Riverpod Providers (lib/core/providers/providers.dart) — state
      → Feature screens (lib/features/)
```

### Key directories

- `lib/core/services/` — FinanceService (main CRUD), BackupService, GoogleDriveService, OCRService, NotificationService, ImportService, PersistenceService
- `lib/core/widgets/` — Shared UI components
- `lib/features/` — Feature modules: auth, dashboard, transactions, budget, stats, settings, import, profile, home, splash
- `lib/models/` — Data models (Transaction, Account, Category, Tag, Budget)

### Database schema (Drift)

Tables: Categories, Tags, Accounts, Transactions, Budgets, Installments. All tables have `userId`, `isDeleted` (soft delete), and `lastUpdated` (sync tracking) fields.

**Cross-isolate writes.** Drift only notifies streams about writes made in their
own isolate, and the `workmanager` tasks (bank capture, PocketBase sync) run in
a separate one — their rows land in SQLite but no `watch()` in the UI isolate
hears about them, so a warm resume shows pre-background state. `main()` covers
this with an `AppLifecycleListener` that calls `markTablesUpdated(db.allTables)`
on resume; any new background writer is already covered by it.

### Installment plans

`Installments` stores a purchase paid in equal monthly rates: total, rate count
and the date of the *first* rate. Everything else — rates paid, still owed, next
due date, active/settled — is derived in `models/installment.dart` from today's
date, so there is no per-rate row, no generated transactions (bank capture
already posts the real charges) and no monthly bookkeeping. `web/src/finance.ts
installmentStatus` is the mirror; keep the two in step, both are tested
(`test/installment_test.dart`, `web/src/finance.test.ts`). Screen:
`/installments`, reached from the dashboard `InstallmentsCard`.

A real charge is tied to a plan by `transactions.installmentId` (nullable, no
FK — sync delivers rows in any order, so a dangling id just reads as unlinked).
Set it from the transaction editor's INSTALLMENT row or from the plan sheet's
linked-payments list. The links are evidence, not arithmetic: they never change
what the plan says you owe, they only expose a rate nobody recorded.

### Transaction types

Three types: income, expense, and transfer (moves money between accounts via `toAccountId`). Expenses are stored as negative amounts.

## Style reference

When modifying UI, consult https://docs.flutter.dev/ui/widgets/material for Material Design 3 widget guidance.
