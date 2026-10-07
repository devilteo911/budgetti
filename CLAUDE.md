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
Drift SQLite + PocketBase (data layer)
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

Tables: Categories, Tags, Accounts, Transactions, Budgets, Installments, PivaProfiles, PivaPayments. All synced tables have `userId`, `isDeleted` (soft delete), and `lastUpdated` (sync tracking) fields.

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

### Partita IVA — data layer

Two synced tables hold what the web Ledger's Partita IVA section writes:
`PivaProfiles` (the one live row: ATECO code, coefficient, fund type and rates,
`incomeCategories`) and `PivaPayments` (one row per deadline that has an
official amount or a payment). Estimates are never stored: tax, contributions
and deadlines are derived at read time from the profile and the ledger. There is
no constraint between the two tables, so a payment can arrive from sync before
its profile; "one live profile" is enforced by whoever saves, not by the schema.

**Names differ.** The Drift tables are `piva_profiles` / `piva_payments`; the
PocketBase collections are `piva_profile` (singular) / `piva_payments`. SQL
written by hand (`adoptLocalData`, schema tests) takes the *table* name; specs,
`syncedCollections`, `sync_failures.collection` and the backup keys take the
*collection* name. `key` is a reserved word in SQLite: quote it in raw SQL.

`incomeCategories` is a JSON-text column (`ListStringConverter`): `null` means
"no categories". In pull it is read by `_toStringListOrNull`, which never throws
and maps a non-list to `null` — an exception in `applyRemotes` would freeze both
sync cursors for good.

**Backup.** Two extra top-level keys, `piva_profile` and `piva_payments`, in the
format the web reads (camelCase, dates as epoch millis, `incomeCategories` an
array or `null`). Both are optional on import: an *absent* key leaves the table
untouched, a *present* one — even `[]` — replaces it. Unlike `installments`,
which is emptied regardless, because the profile is typed in from the
accountant's figures and a backup that never names it says nothing about it.

**Adding a synced collection touches five places:** `syncedCollections` and
`_specs` (`pocketbase_sync_service.dart`), the `TableUpdateQuery` list in
`PocketBaseAutoSync` (same file), `AuthService.adoptLocalData` (table names), and
`BackupService` (export, import, clearing, inserting).

### Transaction types

Three types: income, expense, and transfer (moves money between accounts via `toAccountId`). Expenses are stored as negative amounts.

### E2E: injecting Revolut pushes

A debug build accepts notifications posted from the adb shell as if they were
Revolut's, so the whole capture path runs without a real payment:
`adb shell cmd notification post -S bigtext -t 'Revolut' <unique-tag> 'Hai pagato 10,00 € presso LO CHEF'`
(a unique tag per push — the listener dedupes on the notification key). Needs
notification access granted to the app, and a debug APK signed with the same
cert as the installed build with an equal versionCode (`flutter build apk --debug
--build-number=2003`, then `adb install -r`). The hook is `BuildConfig.DEBUG`-gated
in `RevolutNotificationListener.kt`: it is compiled out of release APKs.

## Style reference

When modifying UI, consult https://docs.flutter.dev/ui/widgets/material for Material Design 3 widget guidance.
