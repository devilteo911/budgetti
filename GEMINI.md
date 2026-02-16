# CLAUDE.md

This file provides guidance to Gemini when working with code in this repository.

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
- **Backend**: Supabase for auth and cloud sync
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

Tables: Categories, Tags, Accounts, Transactions, Budgets. All tables have `userId`, `isDeleted` (soft delete), and `lastUpdated` (sync tracking) fields.

### Transaction types

Three types: income, expense, and transfer (moves money between accounts via `toAccountId`). Expenses are stored as negative amounts.

## Style reference

When modifying UI, consult https://docs.flutter.dev/ui/widgets/material for Material Design 3 widget guidance.
