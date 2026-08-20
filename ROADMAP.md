# Budgetti app — roadmap

Status of the remediation effort that came out of the 2026-08-20 deep-dive
analysis (five subsystem passes, every finding code-verified). The batch
numbering here supersedes any earlier ad-hoc numbering.

**Snapshot at last update** (2026-08-20): schema v16 · 142/142 tests ·
`flutter analyze` 0 errors, 34 info-level lints (avoid_print + naming) ·
branch `fix/app-deep-dive-batch-5`, 7 commits on top of batch 3, not yet
merged/pushed to `main` via `feat/pocketbase-sync`. Server side on
`budgetti-server` branch `feat/lww-guard-batch`, 1 commit.

**Deploy order for batch 3.** The server changes must be live *before* the
matching app build: the new pull filter queries `updated`, a field migration
`1751000009` adds. Ship `server/` first (`docker compose up --build -d`),
then the app.

---

## Done

### Batch 0 — fonts (commit `7294ea8`)
The bundled TTFs were named `-w700`-style while google_fonts matches assets
by `<Family>-<WeightName>` suffix — with `allowRuntimeFetching=false` every
call silently fell back to Roboto. The dev phone masked it (device cache from
pre-bundling network fetches). Renamed to weight names; verified on a
data-cleared install.

### Batch 1 — correctness one-liners
- `a5edd24` — tag filter moved into SQL (`json_each`, whole-element match):
  the in-memory-after-LIMIT filter silently dropped matching rows past page
  one and desynced offsets.
- `b5c1755` — shared classifier (`isIncome`/`isExpense` on the model:
  transfers excluded, sign decides) feeding every aggregate; transfers out
  of the 30-day trend and charts; end-of-day filter range ends (bank drafts
  carry a time-of-day); hero count excludes transfers; `loadMore` in-flight
  flag; `DateFormat` hoisted out of the stats loop.
- `a2f76f6` — draft approval double-booking closed: one `_db.transaction`
  with a `status='pending'` re-check, `_saving` flag on the submit button.
- `6af0330` — Revolut buffer decoded before deletion (a corrupt/truncated
  file was permanently discarded); Kotlin listener writes tmp-then-rename;
  statement-import layer-2 dedup counts only `source='revolut'` drafts.
- `caecd84` — `adoptLocalData` re-stamps `installments` too (restored plans
  were invisible locally yet still pushed — ghost plans); background
  bank-sync isolate uses the persisted user id instead of `'local'`.

### Batch 2 — schema + reactivity
- `072847b` — indexes actually created (v15). The `List<Index>` getters were
  dead code (drift codegen only honors `@TableIndex`), and the v8 step never
  worked either — `Index()` takes a full CREATE statement, was handed only
  the `ON`-clause, a syntax error the swallow-all catch hid. No install had
  ever had an index. Six indexes now (`date DESC`, `account_id`, `user_id`,
  `to_account_id`, `pending.gmail_message_id`, `pending.status`), created on
  fresh installs and upgrades.
- `7cfb2ef` — accounts/categories/tags/budgets are Drift-watched
  StreamProviders. As FutureProviders they only re-ran on manual
  invalidation, so the dashboard balance went stale after every sync (the
  cold-launch sync alone reproduced it). `watchAccounts` pulses on
  transactions too, since balances derive from them.

---

### Batch 3 — sync integrity & scale
All eight items landed; the server half lives in `budgetti-server`
(`pb_hooks/lww_guard.pb.js`, `pb_hooks/enable_batch.pb.js`, migration
`1751000009_updated_autodate.js`) and must be deployed first.

- `a412bdb` — schema v16: `SyncLocks` (one-row cross-isolate mutex) and
  `SyncFailures` (per-row push attempt ledger).
- `b40baa2` — server-side LWW guard + client remote-wins: a push the guard
  rejects now fetches and adopts the remote row (cursor advances) instead of
  skip+rewind, which re-picked the same fight every sync. Cross-isolate lock
  (the workmanager task builds its own service, so `_isSyncing` never saw the
  other isolate; 15-min stale takeover). 401 abort + `sessionExpired`. Pull
  conflict compare truncated to whole seconds (restored backups truncate).
- `34a1b78` — batched push via PB `/api/batch` (PUT upserts, 200/call, failed
  chunk replays row-by-row so per-row accounting survives); batched pull via
  `db.batch()` per collection (kills the O(N²) full-pull watch storm); split
  cursors — pull on PB's server-stamped `updated`, push on local
  `lastUpdated`; dead-lettering after 5 failed attempts at the same stamp, so
  one unpushable row stops pinning the cursor forever.
- `9c9e84c` — Drive restore gets the same adopt → full-push chaser as
  sync-setup; backup export reads all six tables in one `db.transaction`;
  backup JSON encode/decode moved to `Isolate.run`.
- `59fa912` — bounded watches: `transactionsProvider` is a rolling 12-month
  window, stats/charts/category-details watch `periodTransactionsProvider`
  (the selected year), installment screens watch only linked rows + unlinked
  expenses, `filteredTotalsProvider` is a SQL aggregate over the page filter.
- `a5382a5` — session probe: PB never 401s rule-guarded CRUD (an expired
  token reads as *anonymous*, so pulls return an empty 200 that looks like
  "no changes"). `ensureAuthenticated()` calls `auth-refresh` before any data
  traffic — the only place a dead token says 401.

**PocketBase 0.39 JSVM landmines** (verified live, documented in the hook):
hook callbacks are re-parsed, so they must be fully self-contained (no
closure over top-level consts or loop vars); `e.next()` is mandatory or the
write silently no-ops with HTTP 200; `e.record.original()` poisons the
record's pending changes; raw SQL needs `DynamicModel` + `.bind()`; settings
aren't loaded at migration time, so batch is enabled from `onBootstrap`.

---

### Batch 5 — UI / hygiene
All eight items landed.

- `878efdf` — dead code: `auth_check_screen.dart`,
  `expense_distribution_chart.dart`, `AppTheme.darkTheme`, 18 l10n keys with
  no call site, and the `webview_flutter` / `cached_network_image` deps.
- `295f251` — the six `@Deprecated` `AppTheme` colour constants are gone.
  They were `const`, so every widget holding one was pinned to the old
  pure-black palette whatever theme the user picked — the category picker
  and the editor modal were near-unreadable in light mode and the date
  picker forced `ColorScheme.dark` outright. 62 call sites across 10 files
  moved to `Theme.of(context).colorScheme`; hardcoded `Colors.white/black/red`
  ink went with them; text on a user-chosen category swatch uses a
  luminance-picked `_inkOn()`. All 40 `withOpacity` → `withValues(alpha:)`.
  Analyzer: 143 issues → 32.
- `faea112` — `errorText()`: fifteen snackbars interpolated `'$e'` into a
  localized string, and PocketBase's `ClientException` prints the request URL
  and the whole response body. Classifies into network / server / bug, logs
  the real object. `classifyError` is pure and tested (PB reports an
  unreachable host as `ClientException(statusCode: 0)`).
- `21caf55` — one `showAppSheet()` for all 22 bottom sheets. Each re-set the
  background and a top radius at three different radii, none of them the 32
  `bottomSheetTheme` declares; six omitted `useRootNavigator`, letting the
  shell's nav bar paint over the sheet.
- `a1a6bf8` — the three god-builds: `category_editor_modal` 392→78,
  `transaction_page` 299→37 (one `_pickChip(dense:)` for the category and tag
  chips, one `_save()` for the four update/notify/invalidate repeats),
  `stats_screen` 180→28.
- `0d0ba61` — `DiscardGuard` on the six form sheets: a swipe, a barrier tap
  or the back gesture dropped a half-typed form silently. Dirtiness is a
  string snapshot taken at open, so a clean form still closes first try; the
  transaction sheet snapshots only typed fields, since wallet and category
  are auto-filled after the first frame. Plus `ListView.builder` in the
  review inbox, a text-scale-safe filter-chip bar (the fixed 40px box clipped
  the chips), and the app's first `Semantics` — the icon-only nav pill had no
  accessible name though `_NavSlot` already carried the label.
- `d51bb2b` — `finance_math.dart`: `dashboardStats`, `monthlyNetFlow`,
  `categorySpendForMonth`, `statsForPeriod`, `chartSeries` and the month-key
  helpers lifted out of provider bodies, each taking `now` as a parameter —
  the reason none of them were testable before. `providers.dart` re-exports
  the module so no screen import changed (1129 → ~900 lines).
  `category_details_screen`'s private `_last12Months`/`_aggregateByMonth`
  were the same functions again, deleted. 13 new tests.
  `filteredTotals` needed no extraction — batch 3 had already moved it into
  SQL.

**Mirror divergence found, not fixed** (`web/src/finance.ts`). The app
classifies income/expense by *sign* with transfers excluded
(`Transaction.isIncome`/`isExpense`, batch 1); the web's `monthlyFlow` and
`spendByCategory` still branch on `t.type` alone. A row whose stored `type`
disagrees with its amount sign — the case the app's rule exists for — is
counted differently by the two clients. Fixing it is a web change with its
own test expectations, so it is left for a web-side pass.

---

## Batch 4 — capture pipeline hardening (skipped for now, next up)

1. Kotlin key-dedup keeps the *first* version of a notification: if Revolut
   updates hold→settled under the same key, only the hold is buffered.
   Replace the buffered entry on key match (keep `when` from the first post).
2. Gmail: per-message error isolation (one failing `messages.get` currently
   discards the whole pass); persist a high-water mark and query
   `after:<internalDate>` instead of relative `newer_than:7d` (sync off >7d
   = movements never captured); follow `nextPageToken` past 100.
3. Surface OAuth consent expiry (testing-mode 7-day tokens): warning chip in
   Integrations after N consecutive `signInSilently` failures, instead of a
   silent multi-week no-op.
4. `_looksTransactional` gate: a future Widiba template with a keyword-free
   subject is filed `ignored` and permanently excluded from retries — widen
   cautiously or default known senders to `skipped`.
5. `sheets_sync_service.dart` is a live, bidirectional, deletion-capable
   sync (3-way, hash ledger, deletions both ways) wired into dashboard-open
   and every add/approve — with zero tests. Either test the deletion matrix
   or gate sheet-side deletions behind a confirmation.

## Batch 6 — data at rest (app side of the stack review)

1. `android:allowBackup="false"` + `dataExtractionRules` excluding
   `databases/` and `shared_prefs/` — Auto Backup currently ships the full
   Drift DB and the `pb_auth` token to Google cloud backup.
2. PB auth blob from plaintext `SharedPreferences` to
   `flutter_secure_storage` (Keystore-backed); prefs stay for non-secrets.
3. Decide the backup-encryption stance: exports are unencrypted full-ledger
   JSON, then shared/uploaded to Drive. Encrypt with a passphrase-derived
   key, or document Drive-as-trust-boundary as accepted.
4. Scope `usesCleartextTraffic` to the LAN subnet via
   `networkSecurityConfig` (currently global).
5. Delete the dead `budgetti://` / `autoVerify` deep-link intent filters
   (claimable scheme, zero handling code).

---

## Known gaps & accepted risks (not scheduled)

- Per-device default seeding (`_ensureUserDefaults`, `${userId}_cat_Name`
  ids) is not migrated to PB — user-created rows use UUIDs and sync cleanly,
  defaults re-seed per device. Documented in the monorepo CLAUDE.md.
- Cleartext HTTP on the LAN until the Phase-0 physical-server install adds
  TLS — server-side work, tracked in the monorepo, not here.
- Gmail readonly scope stays personal-use-only while the OAuth app remains
  in testing mode (restricted-scope policy).
- Revolut notification capture ceilings (fees/interest never pushed,
  Android-only, nothing before the listener was enabled, nothing while
  access is revoked) — the statement CSV import is the backstop by design.
