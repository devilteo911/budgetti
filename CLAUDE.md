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

### Partita IVA

The phone side of the web Ledger's Partita IVA section (regime forfettario, one
owner, one profile), built in small steps (#16–#21), in four pieces:

- **Data** — `PivaProfiles` and `PivaPayments`, two more specs of the PocketBase
  sync and two more keys of the backup JSON (below, "data layer").
- **Engine** — `lib/models/piva.dart`, pure, a port of `web/src/piva.ts`: *change
  one, change the other*, the same case with the same name in both suites
  (`test/piva_test.dart`, `web/src/piva.test.ts`). The web's simulations are not
  in the app, and **estimates are never stored**: tax, contributions and
  deadlines are derived at every read; only what the accountant says is saved.
- **Screens** — `/piva` (profile, compensi, prospetto, deadlines), the dashboard
  `PivaCard`, `PivaProfileSheet` and `PivaDeadlineSheet`.
- **Reminders** — a local notification before each unpaid deadline, planned by
  the pure `lib/core/services/piva_reminders.dart` (below, "reminders").

### Partita IVA — data layer

Two synced tables hold what the web Ledger's Partita IVA section writes:
`PivaProfiles` (the one live row: ATECO code, coefficient, fund type and rates,
`incomeCategories`, `declaredIncome`) and `PivaPayments` (one row per deadline that has an
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

`declaredIncome` (schema 20) is the gross the owner collected in a year the
ledger does not cover: `{ "<year>": number ≥ 0 | null }`, a number being the
gross (integrativo included for a `cassa`), `null` "derive it from the ledger"
and an absent key "never asked". It is a JSON-text column
(`DeclaredIncomeConverter`) read everywhere through `declaredIncomeFromJson`
(`database.dart`), which never throws, like `_toStringListOrNull`: the converter,
the pull and the backup import all use it, because the generated `fromJson` only
casts and PocketBase hands back whole numbers as ints and keys sorted. A NULL
column is `{}` (`Map<String, double?>`, never null in `PivaProfileData`;
`containsKey` tells *null* from *absent*). Sync: the push sends a non-empty map
**whole** (PocketBase replaces the json object, never merges it) and **omits the
key** for a NULL or empty one — an omitted field keeps the server's value, so a
phone that never learned the web's figure cannot erase it, and it learns the
figure the server kept from the record its own push was answered with
(`PushOutcome.record`; a pull would never bring it back, the pushed row's new
`updated` is behind the cursor), writing only that column so `lastUpdated` stays; the pull keeps the
local value when the record has no such key (a server without
`1751000013_piva_declared_income.js` answers 200 to a write that carries it and
never returns it back). The server migration does not touch `updated`, so the
upgrade makes one sync re-pull `piva_profile` from epoch: `pb_piva_profile_repulled`
(a pref next to the cursors, default false, set by the sync once that pull ran).
`savePivaProfile` writes the map as given and `PivaProfileInput.declaredIncome`
is required, so a save can never forget it; the sheet only passes it through.

**Backup.** Two extra top-level keys, `piva_profile` and `piva_payments`, in the
format the web reads (camelCase, dates as epoch millis, `incomeCategories` an
array or `null`, `declaredIncome` an object — its `null` values kept — or `null`,
absent on a v0.7 backup). Both are optional on import: an *absent* key leaves the table
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
acconti, the merge with the accountant's saved amounts, and the declared year:
`compensiForYear` is the one read of a concluded year — the declared figure
divided once by `1 + integrativo %` for a `cassa`, else the ledger's — with
`declaredFor`, the declared-aware `integrativeCollected`, `askDeclaredIncome` and
`ledgerCovers`) — without the web's
simulations and `writeFailure`; `parseProfileForm` (the profile form's rules)
is in the same file. `test/piva_test.dart` ports the web cases with the same
names and the same figures to the cent (**change one, change both**), plus
eighteen cases the web suite does not have yet: sixteen on the JavaScript-to-Dart
traps (`trappola: …`, among them four for the declared year: a UTC-flagged
`ledgerStart` and `now`, a 41.600 declared on a cassa at 4%, `declaredFor`'s
guards), `estimateYear, cassa a zero` and `parseProfileForm: declaredIncome passa
intatto`; the artigiani case with saldo and acconti above the minimale was also
written for the web suite, so the two should be kept in step. The seven cases the
web added with its declared year (`compensiForYear …`, `askDeclaredIncome …`, the
two `deadlines … dichiarato …` calendars) are here under the same names; its
`declaredFromForm` case has no twin until the phone has the field (#30). Every fiscal figure lives in the one year-keyed table
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
because the acconti of a year look at the years before it — and `getLedgerStart` /
`watchLedgerStart`, the date of the first live transaction of **any type**, which
`askDeclaredIncome` takes as an input because the income rows alone would put the
start too late) and the five providers
in `providers.dart` sit on Drift streams, so a sync refreshes them; none is
invalidated by hand. `pivaViewProvider(year)` is where the derivation is
memoised: it recomputes only when the profile, the payments or the income change
or the year does, never on a rebuild, and reads the clock once per derivation.
`lib/features/piva/piva_view.dart` is the pure derivation (tiles, prior year cut
at the same day, reconciliation, the estimate with the deductible contributions,
made on `compensiForYear` for every year like the web's `PivaForecast.tsx`; the
tiles of a declared year still read the ledger until #30) and mirrors the calculations the web does inside `PivaIncome.tsx` and
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
for artigiani and commercianti. The sheet passes the profile's `declaredIncome`
through untouched (no field yet, not part of the dirty check). `FinanceService.savePivaProfile` keeps **one live
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

### Partita IVA reminders

A local notification before every unpaid deadline: 30, 7 and 1 day before and on
the day, at 9:00 **Europe/Rome** (`tz.local` is pinned there in
`NotificationService.init`, wherever the phone is). Title "Partita IVA · scade tra N
giorni" / "scade domani" / "scade oggi" (ARB keys `pivaRem*`); body `label · DD/MM/YYYY · amount`, "circa … (stima)"
while the amount is an estimate and plain once it is the accountant's. A tap opens
`/piva` on the deadlines.

- **The plan is pure** — `lib/core/services/piva_reminders.dart`: `planPivaReminders`
  and `diffPivaReminders` read no clock, database or `BuildContext` (`now` and the
  language come in, so the same code runs in the UI isolate and the workmanager
  one). Only `due` deadlines with a day and an amount above zero count — never a
  paid or a past one — and a reminder whose instant is not after now is skipped,
  never caught up ("in 7 days" shown late is false). At most 32 are kept (the
  nearest, `pivaReminderCap`). `now` for the engine and the planner is a plain
  wall-clock `DateTime` built from the Europe/Rome components, not a `TZDateTime`
  (the engine calls `toLocal()`); `fireAt` is a UTC `DateTime` used as a carrier of
  year-month-day-hour, so no instant is compared and DST never enters.
- **Ids** are negative, from a SHA-256 of `paymentId ?? key` + days before (not
  `hashCode`: stable across Dart versions and restarts). The other notifications of
  the app use non-negative ids, and the diff only ever looks at the negative ones:
  `NotificationService.syncPivaReminders(plan)` cancels and schedules just the
  difference, and an empty plan clears the reminders without touching anything else.
  Reminders that fire together stack in a group whose summary we post ourselves
  (same payload, so tapping the closed stack opens the same screen). The body goes
  in a big-text style (`pivaReminderDetails(body:)`), or the shade clips it at two
  lines and cuts the "(stima)" off an estimate; the summary has none.
- **Replan** — `pivaRemindersSyncProvider` (`notification_logic.dart`, kept alive by
  `container.listen` in `main.dart`) listens to the profile, the payments, the
  income ledger and the language; each change re-arms one 2 s debounce, and it is
  armed at construction too (every launch). It plans only when all three sources
  have a value (an empty plan would clear every reminder); a `null` profile is a
  value and does clear. The tail of `pbSyncTask` replans from the database too,
  for an official amount pulled while the app was closed.
- **Switch** — pref `piva_reminders_enabled` (default on), a row in Settings →
  Preferences. It only counts under the general notifications switch and with a
  profile; the row says why when it is off ("no profile", "turn notifications on
  first", "blocked by the system" with the permission fix row).
- **Tap** — the payload starts with `piva:`; `openFromNotification` routes it to
  `/piva?section=deadlines` (`PivaScreen.openDeadlines` scrolls to the deadlines),
  every other payload (bank drafts) still opens the review inbox, and the daily
  reminder, which has none, only brings the app up.
- **Inexact, so late.** Scheduled with `inexactAllowWhileIdle`: an exact alarm needs
  `SCHEDULE_EXACT_ALARM`, whose absence made `zonedSchedule` throw. Android delivers
  an inexact alarm at the *end* of a window of 0.75 × the time left when it was
  scheduled, at most 1 h. Measured on the test phone, idle: a 9:00 reminder planned
  days ahead (`window=+1h0m0s`) appeared at **10:00:03**; one rescheduled ten minutes
  before (`window=+7m26s`) at **9:07:35**; one rescheduled 3m47s before (`window=+2m50s`)
  at 9:02:51. So "at 9:00" means "between 9:00 and 10:00". Left as is on purpose; an
  exact or alarm-clock mode is the way out.
- Ceilings: the diff compares id, title, body and payload, not the group, so a
  reminder keeps the group it was scheduled with when a twin appears or goes
  (`ponytail:` note in `syncPivaReminders`); the estimates move with `now`, so the
  estimate reminders are rewritten as months pass.

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

### E2E: the deadline reminders

No root needed. **Read what is pending:** every replan of a debug build logs one
line, `adb logcat -d | grep -F "PIVA reminders"` →
`pending=N cancelled=N scheduled=N [id @ instant, …]` (a no-op round says `0 0`);
`adb shell dumpsys alarm | grep -A2 "com.devilteo911.budgetti.budgetti}"` lists the
alarms themselves (tag `…ScheduledNotificationReceiver`, `window=` is the inexact
window, see "reminders"); `adb shell dumpsys notification --noredact` reads what
was posted. `run-as` is blocked on this phone, and `BOOT_COMPLETED` cannot be sent
from the shell, so a reboot is only provable by really rebooting.

**Make one fire:** move the phone's clock, then give the alarm a short window by
(re)scheduling it a few minutes before its time — a reminder scheduled days ahead
keeps its 1 h window and shows up an hour late. The cheapest reschedule is the
Preferences row itself: switch "Scadenze partita IVA" off and on (cancels all and
schedules them again at the moved clock); changing the language does the same.

```
adb shell settings put global auto_time 0
adb shell cmd alarm set-time $(( $(TZ=Europe/Rome date -d '2026-10-08 08:56' +%s) * 1000 ))
# then the off/on above, before 9:00: the stack lands at 9:00 + 0.75 x the time left
```

`am force-stop` drops every alarm and opening the app brings them back within
seconds; `adb install -r` keeps them. **Cold-start tap:** `adb shell am kill <pkg>`
(it only works once the app has been in the background a while; `am crash` does
not kill it), see that `pidof <pkg>` is empty, that `dumpsys alarm` and the shade
still hold the reminders, and tap the stack: the app starts straight on the
deadlines.

**Put the clock back, always, and prove it:**

```
adb shell settings put global auto_time 1
adb shell cmd time_detector set_auto_detection_enabled true
adb shell date; date            # the two must agree to the second
```

An estimate's amount depends on `now`, so a moved clock also rewrites the estimate
reminders.

## Style reference

When modifying UI, consult https://docs.flutter.dev/ui/widgets/material for Material Design 3 widget guidance.
