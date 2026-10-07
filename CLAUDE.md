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
- `lib/features/` — Feature modules: auth, dashboard, transactions, budget, stats, settings, import, profile, home, splash, piva
- `lib/models/` — Data models (Transaction, Account, Category, Tag, Budget, Installment) and `piva.dart`, the pure Partita IVA engine

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

### Partita IVA engine

`lib/models/piva.dart` is the pure Dart mirror of `web/src/piva.ts` (imposta
sostitutiva, contributions for the four fund types, the calendar of saldi and
acconti, the merge with the accountant's saved amounts) — without the web's
simulations and `writeFailure`; `parseProfileForm` (the profile form's rules)
is in the same file. `test/piva_test.dart` ports the web cases with the same
names and the same figures to the cent (**change one, change both**), plus
thirteen cases the web suite does not have yet: twelve on the JavaScript-to-Dart
traps (`trappola: …`) and `estimateYear, cassa a zero`; the artigiani case with saldo
and acconti above the minimale was also written for the web suite, so the two
should be kept in step. Every fiscal figure lives in the one year-keyed table
at the top of the file, with its source; a new year is one new row.

No Drift, no Flutter, no I/O, and no `DateTime.now()`: `now` and `today` are
always injected. Days are local `DateTime?` of which only year, month and day
count — compared as `year * 10000 + month * 100 + day`, never as instants — and
`kind`, `fundType` and `key` stay strings, byte for byte as on the server.

Three numeric rules not to break, each with a test that goes red: `_round2`
redoes JavaScript's `Math.round` (halves go towards +infinity, so `-12.5` is
`-12`; Dart's `round()` gives `-13`), and it is the only rounding in the file;
sums and derived fields follow the web's order of operations (month sum, then
divide, then round; every derived field from already-rounded values); and the
final ordering of the calendar breaks ties by generation index, because Dart's
`List.sort` is not guaranteed stable.

The suite does not pin a time zone; rerun it under several (the `fuso del run`
test checks the zone really reached the tester):

```
TZ=UTC PIVA_EXPECT_OFFSET_MIN=0 flutter test test/piva_test.dart
TZ=Pacific/Auckland PIVA_EXPECT_OFFSET_MIN=780 flutter test test/piva_test.dart
TZ=America/Los_Angeles PIVA_EXPECT_OFFSET_MIN=-480 flutter test test/piva_test.dart
TZ=Europe/Rome PIVA_EXPECT_OFFSET_MIN=60 flutter test test/piva_test.dart
```

### Partita IVA screen

`/piva` (`lib/features/piva/`, a top-level route outside the
shell like `/installments`) is reached from the `PivaCard` on the dashboard —
shown only when a live profile exists, always on the current year — and from the
permanent "Partita IVA" entry in Settings, which is also how the empty state is
reachable. It shows the profile, the compensi of the chosen year (stepper from
`startYear` to the current year, four tiles, a chart against the year before,
and for a `cassa` with an integrativo the bank-vs-compensi reconciliation) and
the prospetto of the year.

Reads live in `FinanceService` (`get`/`watch` of `PivaProfile`, `PivaPayments`
and `PivaIncome` — the last one is the whole income history with no date window,
because the acconti of a year look at the years before it) and the five providers
in `providers.dart` sit on Drift streams, so a sync refreshes them; none is
invalidated by hand. `pivaViewProvider(year)` is where the derivation is
memoised: it recomputes only when the profile, the payments or the income change
or the year does, never on a rebuild, and reads the clock once per derivation.
`lib/features/piva/piva_view.dart` is the pure derivation (tiles, prior year cut
at the same day, reconciliation, the estimate with the deductible contributions)
and mirrors the calculations the web does inside `PivaIncome.tsx` and
`PivaForecast.tsx` — change one, change the other (`test/piva_view_test.dart`).

Fiscal terms ("Compensi", "Imposta sostitutiva", the fund names…) are plain Dart
constants in `piva_format.dart`, identical in both languages, not ARB keys.
`pivaNumber` there is the only place a non-monetary number of this feature
becomes text (`67`, not `67.0`; `26,07` in Italian).

**The profile is created and edited on the phone** from `PivaProfileSheet`
(`piva_profile_sheet.dart`): the "Imposta il profilo" button of the empty state
and the edit action in the profile summary open it, with `existing` null to
create. It validates nothing itself: `parseProfileForm` in `lib/models/piva.dart`
is the mirror of the web's function of the same name and returns a
`ProfileFormError` code that the sheet turns into its (translated) message — the
rules and their order are the web's, change one, change both. A `cassa`'s own
fields are saved blank/0 for any other fund, and the INPS reduction only counts
for artigiani and commercianti. `FinanceService.savePivaProfile` keeps **one live
row**: it updates the newest and logically deletes (stamped, so the deletion
syncs) any other live row — two devices that each created a profile offline end
with one. Numbers go back into the fields with `pivaNumber`, never fixed decimals:
`parseAmount` reads a three-digit tail as thousands. The form's message and Save
button sit outside the scroll view, so an error cannot push the button off the
screen. Like every sheet guarded by `DiscardGuard`, closing with edits asks first
on the back key; a downward drag on a dirty sheet just doesn't close it.

**Deadlines are managed on the phone** (`piva_deadlines_section.dart`, mounted under
the prospetto, and `piva_deadline_sheet.dart`; the mirror is
`web/src/components/PivaForecast.tsx`). The rows are the engine's `deadlines(...)`
and nothing fiscal is computed in the widgets. The four states: `due`, `paid`,
`overdue` (past, unpaid, **official**: the only red in the section) and
`unrecorded` (past, unpaid, still an *estimate* — most likely paid and never
entered, so neutral, never red, and not counted in "Da versare"). A tap on a row
opens the sheet; "Segna pagata" on an estimate opens the sheet with the estimate
prefilled (saving freezes it as the official amount, so it asks first), on an
official row it writes at once, and "Annulla pagamento" takes the payment back
leaving the row official. `FinanceService.savePivaPayment` / `deletePivaPayment`
write the whole row (a delete is a stamped soft delete) with both days at **local
noon**, as the web's `dayIso`, so the other client reads the same day; `dueDate`
can be null (a row created through the API or the admin UI) and then reads "Senza
data", never "next" and never past. An amount of 0 is a real answer. "Torna alla
stima" is offered only if `canRevertToEstimate` — a recomputation of the engine
without that row — still finds an estimate with the same `key` (an official
contributions amount also moves the estimated tax rows); otherwise it is "Elimina".
Destructive actions ask first. `nextPivaDeadline` is the one definition of the
"next deadline" (first unpaid row from today on that has a day), used by the third
tile and by the dashboard `PivaCard`, whose extra line is absent — not blank — when
there is none. The sheet reads its form once, at open: a sync that changes the row
underneath does not touch what is being typed, and the phone's save then wins whole
(newer `lastUpdated`); a *rejected* LWW write (the web was newer) is applied by the
sync and shows nothing on this screen, as for every other collection. A label that
wraps keeps each `·` glued to the word before it (`pivaNoBreak`, display only).

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
