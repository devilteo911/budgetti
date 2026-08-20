// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonClose => 'Close';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonError => 'Error';

  @override
  String get commonNone => 'None';

  @override
  String get commonAll => 'All';

  @override
  String get commonIncome => 'Income';

  @override
  String get commonExpense => 'Expense';

  @override
  String get commonTransfer => 'Transfer';

  @override
  String get commonDate => 'Date';

  @override
  String get commonCategory => 'Category';

  @override
  String get commonWallet => 'Wallet';

  @override
  String get commonTags => 'Tags';

  @override
  String get commonNoData => 'No data';

  @override
  String get commonSystem => 'System';

  @override
  String get authConnectionError => 'Connection Error';

  @override
  String get authProfileMissing => 'Profile missing (Error)';

  @override
  String authDetailedError(String error) {
    return 'Detailed error: $error';
  }

  @override
  String get authLoginFailed => 'Login failed';

  @override
  String get authCannotReachServer =>
      'Cannot reach server. Check the URL in Settings > Integrations.';

  @override
  String get authLoginTagline => 'Manage your finances like a pro';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authLogIn => 'Log In';

  @override
  String get authSetServer => 'Set server';

  @override
  String get authWhoAreYou => 'Who are you?';

  @override
  String get authChooseUsername => 'Choose a Username';

  @override
  String get authUsernameHint => 'Tell us what to call you in the app.';

  @override
  String get authUsername => 'Username';

  @override
  String authUsernameMinLength(int min) {
    return 'Username must be at least $min characters';
  }

  @override
  String get authGetStarted => 'Get Started';

  @override
  String get authSyncSetupTitle => 'Set up sync';

  @override
  String get authSyncSetupSubtitle =>
      'How should this device and the server line up?';

  @override
  String get authCheckingServer => 'Checking the server…';

  @override
  String get authServerUnreachable => 'Could not reach the server.';

  @override
  String authServerHasData(int count) {
    return 'The server already has data for this account ($count transactions).';
  }

  @override
  String get authServerNoData => 'The server has no data for this account yet.';

  @override
  String get authRetrySubtitle => 'Check the server connection again';

  @override
  String get authUseServerData => 'Use the server\'s data';

  @override
  String authUseServerDataSubtitle(int count) {
    return 'Download everything to this device ($count transactions)';
  }

  @override
  String get authUploadDeviceData => 'Upload this device\'s data';

  @override
  String authUploadDeviceDataSubtitle(int count) {
    return 'Push all local data to the server ($count transactions)';
  }

  @override
  String get authRestoreBackup => 'Restore a backup file';

  @override
  String get authRestoreBackupSubtitle =>
      'Import a Budgetti JSON backup, then upload it';

  @override
  String get authContinueWithoutSync => 'Continue without syncing';

  @override
  String get authContinueWithoutSyncSubtitle =>
      'Keep local and server data as they are for now';

  @override
  String get authActionDownload => 'Download';

  @override
  String get authActionUpload => 'Upload';

  @override
  String get authActionRestore => 'Restore';

  @override
  String authActionFailed(String action, String error) {
    return '$action failed: $error';
  }

  @override
  String get authProfileTitle => 'Profile';

  @override
  String get authUser => 'User';

  @override
  String get authAvatarUpdated => 'Profile picture updated';

  @override
  String authAvatarSaveError(String error) {
    return 'Error saving image: $error';
  }

  @override
  String get authSignOut => 'Sign Out';

  @override
  String get authNavDashboard => 'Dashboard';

  @override
  String get authNavHistory => 'History';

  @override
  String get authNavStats => 'Stats';

  @override
  String get authNavSettings => 'Settings';

  @override
  String get dashConnectivityIssue => 'Connectivity Issue';

  @override
  String get dashConnectivityMessage =>
      'Unable to reach the server. Please check your connection.';

  @override
  String get dashSyncFailed => 'Sync Failed';

  @override
  String get dashNoAccounts => 'No accounts found';

  @override
  String get dashErrorCalculatingStats => 'Error calculating stats';

  @override
  String get dashSetUpBudgets => 'Set up budgets';

  @override
  String get dashSetUpBudgetsSubtitle => 'Track category spending each month';

  @override
  String get dashMonthlyBudgetLabel => 'Monthly budget';

  @override
  String get dashCategoriesLabel => 'Categories';

  @override
  String get dashTotalBalance => 'Total Balance';

  @override
  String get dashTrend30d => '30d';

  @override
  String get dashWalletsLabel => 'Wallets';

  @override
  String get dashWalletsLoadError => 'Couldn\'t load wallets';

  @override
  String get dashNoWallets => 'No wallets yet';

  @override
  String dashWalletsMore(int count) {
    return '$count more';
  }

  @override
  String get dashStatIn => 'In';

  @override
  String get dashStatOut => 'Out';

  @override
  String get dashStatNet => 'Net';

  @override
  String get dashStillOwedLabel => 'Still owed';

  @override
  String dashPerMonth(String amount) {
    return '$amount / month';
  }

  @override
  String get dashPlansLabel => 'Plans';

  @override
  String dashMorePlans(int count) {
    return '+$count more';
  }

  @override
  String dashNextDue(String date) {
    return 'Next $date';
  }

  @override
  String get dashRecentLabel => 'Recent';

  @override
  String dashLastCount(int count) {
    return 'Last $count';
  }

  @override
  String get dashAllLabel => 'All';

  @override
  String get dashNoTransactions => 'No transactions yet';

  @override
  String get dashYesterdayShort => 'YDA';

  @override
  String dashDaysAgoShort(int days) {
    return '${days}D';
  }

  @override
  String get budgetScreenTitle => 'Budgets';

  @override
  String get budgetSortUtilization => 'Utilization';

  @override
  String get budgetSortAlphabetical => 'Alphabetical';

  @override
  String get budgetSortLimitHighLow => 'Limit: High to Low';

  @override
  String get budgetSortLimitLowHigh => 'Limit: Low to High';

  @override
  String get budgetTracked => 'TRACKED';

  @override
  String get budgetSectionUnset => 'UNSET';

  @override
  String get budgetNoCategories => 'NO CATEGORIES';

  @override
  String get budgetEmptyHint =>
      'Add expense categories first to start tracking budgets.';

  @override
  String get budgetErrorLabel => 'ERROR';

  @override
  String get budgetUpdated => 'Budget updated';

  @override
  String budgetSaveError(String error) {
    return 'Error saving budget: $error';
  }

  @override
  String get budgetMonthlyLimit => 'MONTHLY LIMIT';

  @override
  String get budgetAmountHint => '0.00';

  @override
  String get budgetEnterLimit => 'Enter limit';

  @override
  String get budgetInvalid => 'Invalid';

  @override
  String get budgetMustBePositive => 'Must be positive';

  @override
  String get budgetClear => 'Clear';

  @override
  String get budgetUpdate => 'Update';

  @override
  String get budgetCleared => 'Budget cleared';

  @override
  String budgetUtilizationOf(String month) {
    return 'UTILIZATION  ·  $month';
  }

  @override
  String budgetNoBudgetsSet(String month) {
    return 'NO BUDGETS SET  ·  $month';
  }

  @override
  String get budgetTapToSet => 'Tap a category below to set a limit.';

  @override
  String get budgetSpent => 'SPENT';

  @override
  String get budgetBudgeted => 'BUDGETED';

  @override
  String get budgetRemaining => 'REMAINING';

  @override
  String get budgetOver => 'OVER';

  @override
  String get budgetNoLimit => 'NO LIMIT · TAP TO SET';

  @override
  String get budgetSet => 'SET';

  @override
  String get instScreenTitle => 'Installments';

  @override
  String get instActive => 'ACTIVE';

  @override
  String get instSettled => 'SETTLED';

  @override
  String get instStillOwed => 'STILL OWED';

  @override
  String instMonthlyActive(String amount, int count) {
    return '$amount / month · $count active';
  }

  @override
  String get instDeletePlanTitle => 'Delete plan?';

  @override
  String instDeletePlanBody(String name) {
    return '\"$name\" will be removed.';
  }

  @override
  String instPerMo(String amount) {
    return '$amount/mo';
  }

  @override
  String instPaidOf(int paid, int total) {
    return '$paid/$total paid';
  }

  @override
  String instLinkedCount(int count) {
    return '· $count linked';
  }

  @override
  String get instSettledLabel => 'Settled';

  @override
  String instRemainingNext(String amount, String date) {
    return '$amount left · next $date';
  }

  @override
  String get instNoPlans => 'NO PLANS';

  @override
  String get instEmptyHint =>
      'Add a purchase you are paying in monthly rates and this tracks what you still owe.';

  @override
  String get instAddPlan => 'Add a plan';

  @override
  String instSaveError(String error) {
    return 'Error saving plan: $error';
  }

  @override
  String get instNewPlan => 'NEW PLAN';

  @override
  String get instEditPlan => 'EDIT PLAN';

  @override
  String get instWhatFor => 'What is it for';

  @override
  String get instWhatForHint => 'Sofa, laptop, holiday…';

  @override
  String get instRequired => 'Required';

  @override
  String get instTotal => 'Total';

  @override
  String get instInvalid => 'Invalid';

  @override
  String get instMustBePositive => 'Must be positive';

  @override
  String get instAtLeast1 => 'At least 1';

  @override
  String get instRatesLabel => 'Rates';

  @override
  String get instPerRateHint => 'Monthly rate appears here';

  @override
  String instPerMonth(String amount) {
    return '$amount / month';
  }

  @override
  String get instFirstRateOn => 'First rate on';

  @override
  String get instCategoryOptional => 'Category (optional)';

  @override
  String get instWalletOptional => 'Wallet (optional)';

  @override
  String get instUpdatePlan => 'Update plan';

  @override
  String instLinkedPaymentsOf(int linked, int due) {
    return 'LINKED PAYMENTS · $linked/$due';
  }

  @override
  String get instAllAccounted => 'Every rate due so far is accounted for.';

  @override
  String instMissingRates(int missing, int due) {
    return '$missing of the $due rates due so far have no transaction attached.';
  }

  @override
  String get instUnlink => 'Unlink';

  @override
  String get instNoCandidates => 'No unlinked expenses to attach.';

  @override
  String get instAttachPayment => 'Attach a payment';

  @override
  String get importSelectWalletError => 'Please select a wallet';

  @override
  String importSuccess(int count) {
    return 'Successfully imported $count transactions';
  }

  @override
  String importError(String error) {
    return 'Error importing: $error';
  }

  @override
  String get importSelectWalletTitle => 'Select Wallet';

  @override
  String get importPreviewTitle => 'Import Preview';

  @override
  String get importToWallet => 'Import to Wallet';

  @override
  String importFound(int count) {
    return 'Transactions found: $count';
  }

  @override
  String importTotal(String amount) {
    return 'Total: $amount';
  }

  @override
  String get importConfirm => 'Confirm Import';

  @override
  String get chartNoDataYear => 'No data available for this year';

  @override
  String chartWeekOf(String date) {
    return 'Week of $date';
  }

  @override
  String get chartExpenses => 'Expenses';

  @override
  String get chartIncome => 'Income';

  @override
  String chartWeekShort(int week) {
    return 'W$week';
  }

  @override
  String get uiSelectCategory => 'Select Category';

  @override
  String get uiNoCategories => 'No categories found';

  @override
  String get uiSelectWallet => 'Select Wallet';

  @override
  String get uiAllWallets => 'All Wallets';

  @override
  String get notifBackupDone => 'Auto-backup completed successfully.';

  @override
  String get notifBackupFailed => 'Auto-backup failed. Check settings.';

  @override
  String get notifBudgetAlertTitle => 'Budget Alert';

  @override
  String notifBudgetReached(String category) {
    return 'You\'ve reached your budget for $category!';
  }

  @override
  String notifBudgetUsedPct(String percent, String category) {
    return 'You\'ve used $percent% of your $category budget.';
  }

  @override
  String get notifDailyTitle => 'Track your expenses';

  @override
  String get notifDailyBody => 'Don\'t forget to log your spending for today!';

  @override
  String get notifBackupProgressTitle => 'Backup in progress...';

  @override
  String get notifBackupSuccessTitle => 'Backup Successful';

  @override
  String get notifBackupFailedTitle => 'Backup Failed';

  @override
  String get notifBackupProgressBody => 'Saving your data safely.';

  @override
  String get notifBackupSuccessBody => 'Your data has been backed up.';

  @override
  String get notifBackupErrorBody => 'There was an error during backup.';

  @override
  String get notifEmailIncome => 'Credit received';

  @override
  String get notifEmailReview => 'Transfer to review';

  @override
  String get notifEmailExpense => 'Payment recorded';

  @override
  String get setSettings => 'Settings';

  @override
  String get setAccount => 'Account';

  @override
  String get setProfile => 'Profile';

  @override
  String get setAppearance => 'Appearance';

  @override
  String get setAppearanceSubtitle => 'Palette, theme, effects';

  @override
  String get setPreferences => 'Preferences';

  @override
  String get setPreferencesSubtitle => 'Currency, scanner, notifications';

  @override
  String get setIntegrationsBackup => 'Integrations & Backup';

  @override
  String get setIntegrationsBackupSubtitle => 'Drive, Sheets, auto backup';

  @override
  String get setData => 'Data';

  @override
  String get setAbout => 'About';

  @override
  String get setSourceCode => 'Source code';

  @override
  String get setSignOut => 'Sign out';

  @override
  String get setImportQuicken => 'Import Quicken (QIF)';

  @override
  String get setImportQuickenSubtitle => 'Load transactions from a .qif file';

  @override
  String get setSelectQifFile => 'Please select a .qif file';

  @override
  String get setLanguage => 'Language';

  @override
  String get setPalette => 'Palette';

  @override
  String get setBrightness => 'Brightness';

  @override
  String get setThemeLight => 'Light';

  @override
  String get setThemeDark => 'Dark';

  @override
  String get setEffects => 'Effects';

  @override
  String get setAmoledBlack => 'AMOLED black';

  @override
  String get setAmoledBlackSubtitle => 'Pure black background in dark mode';

  @override
  String get setLiquidGlass => 'Liquid glass';

  @override
  String get setLiquidGlassSubtitle => 'Frosted blur on nav bar and sheets';

  @override
  String get setCategories => 'Categories';

  @override
  String get setTags => 'Tags';

  @override
  String get setWallets => 'Wallets';

  @override
  String get setNoCategories => 'No categories yet';

  @override
  String get setCreateFirstCategory => 'Create your first category';

  @override
  String get setNoTags => 'No tags yet';

  @override
  String get setNoWallets => 'No wallets yet';

  @override
  String get setExpenses => 'Expenses';

  @override
  String get setIncome => 'Income';

  @override
  String get setRestoreDefaults => 'Restore Defaults';

  @override
  String get setRestoreDefaultsTitle => 'Restore Defaults?';

  @override
  String get setRestoreCategoriesBody =>
      'This will restore default categories if they were deleted or modified. Your custom categories will not be affected.';

  @override
  String get setRestoreTagsBody =>
      'This will restore default tags if they were deleted or modified. Your custom tags will not be affected.';

  @override
  String get setRestore => 'Restore';

  @override
  String get setCategoriesRestored => 'Default categories restored';

  @override
  String get setTagsRestored => 'Default tags restored';

  @override
  String get setDeleteCategoryTitle => 'Delete Category?';

  @override
  String get setDeleteTagTitle => 'Delete Tag';

  @override
  String get setDeleteWalletTitle => 'Delete Account';

  @override
  String setDeleteConfirmBody(String name) {
    return 'Are you sure you want to delete \'$name\'?';
  }

  @override
  String setDeleteWalletBody(String name) {
    return 'Delete \'$name\'? This won\'t delete transactions but they might become unassigned.';
  }

  @override
  String setErrorWithDetails(String error) {
    return 'Error: $error';
  }

  @override
  String get setNewCategory => 'New Category';

  @override
  String get setEditCategory => 'Edit Category';

  @override
  String get setFieldName => 'Name';

  @override
  String get setFieldType => 'Type';

  @override
  String get setFieldDescription => 'Description (optional)';

  @override
  String get setFieldSelectIcon => 'Select icon';

  @override
  String get setCategoryNameHint => 'e.g. Shopping, Rent...';

  @override
  String get setCategoryDescriptionHint =>
      'Add a short note about this category...';

  @override
  String get setSaveCategory => 'Save Category';

  @override
  String get setSelectColor => 'Select Color';

  @override
  String get setNewTag => 'New Tag';

  @override
  String get setEditTag => 'Edit Tag';

  @override
  String get setTagName => 'Tag Name';

  @override
  String get setColor => 'Color';

  @override
  String get setCreateTag => 'Create Tag';

  @override
  String get setUpdateTag => 'Update Tag';

  @override
  String get setNewWallet => 'New Account';

  @override
  String get setEditWallet => 'Edit Account';

  @override
  String get setWalletNameHint => 'Account Name (e.g. PayPal, Bank)';

  @override
  String get setInitialAmount => 'Initial Amount';

  @override
  String get setStartingDate => 'Starting Date';

  @override
  String get setAllTransactions => 'All transactions';

  @override
  String get setSetAsDefault => 'Set as default';

  @override
  String get setCreateWallet => 'Create Account';

  @override
  String get setUpdateWallet => 'Update Account';

  @override
  String setWalletSince(String date) {
    return 'From $date';
  }

  @override
  String get setGeneral => 'General';

  @override
  String get setCurrency => 'Currency';

  @override
  String get setSelectCurrency => 'Select Currency';

  @override
  String get setCurrencyEur => 'Euro';

  @override
  String get setCurrencyUsd => 'US Dollar';

  @override
  String get setCurrencyGbp => 'British Pound';

  @override
  String get setCurrencyJpy => 'Japanese Yen';

  @override
  String get setNotifications => 'Notifications';

  @override
  String get setFixPermissions => 'Fix Permissions';

  @override
  String get setFixPermissionsSubtitle => 'Tap to enable notifications';

  @override
  String get setPushNotifications => 'Push Notifications';

  @override
  String get setPushNotificationsSubtitle => 'Main system alerts';

  @override
  String get setBudgetAlerts => 'Budget Alerts';

  @override
  String get setBudgetAlertsSubtitle => 'Limit thresholds';

  @override
  String get setDailyReminder => 'Daily Reminder';

  @override
  String get setDailyReminderSubtitle => 'Manual logging';

  @override
  String get setReminderTime => 'Reminder Time';

  @override
  String get setIntegrations => 'Integrations';

  @override
  String get setCloudSync => 'Cloud sync';

  @override
  String get setServer => 'Server';

  @override
  String get setNotConfigured => 'Not configured';

  @override
  String get setSyncNow => 'Sync now';

  @override
  String get setPushEverything => 'Push everything';

  @override
  String get setPushEverythingSubtitle =>
      'Upload all local data (categories, tags, wallets, transactions, budgets) to the server';

  @override
  String get setPullEverything => 'Pull everything';

  @override
  String get setPullEverythingSubtitle =>
      'Download all server data to this device';

  @override
  String get setConfigureServerFirst => 'Configure the server URL first';

  @override
  String setSyncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get setPbServerTitle => 'PocketBase server';

  @override
  String get setPbHost => 'Host or IP';

  @override
  String get setPbPort => 'Port';

  @override
  String get setGoogleDrive => 'Google Drive';

  @override
  String get setConnectDrive => 'Connect Google Drive';

  @override
  String get setConnectDriveSubtitle => 'Cloud backup & restore';

  @override
  String get setDriveConnected => 'Drive Connected';

  @override
  String get setBackupNow => 'Backup now';

  @override
  String get setRestoreFromBackup => 'Restore from backup';

  @override
  String get setGoogleConnected => 'Successfully connected to Google';

  @override
  String setSignInFailed(String error) {
    return 'Sign in failed: $error';
  }

  @override
  String get setSignInCancelled => 'Sign-in was cancelled';

  @override
  String get setBackupDone => 'Backup successful';

  @override
  String setBackupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get setNoBackups => 'No backups found';

  @override
  String get setSelectBackup => 'Select Backup';

  @override
  String get setUnknown => 'Unknown';

  @override
  String get setRestoreDone => 'Restore successful';

  @override
  String setRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get setGoogleSheets => 'Google Sheets';

  @override
  String get setSpreadsheet => 'Spreadsheet';

  @override
  String get setSheetsConfig => 'Google Sheets Config';

  @override
  String get setSpreadsheetId => 'Spreadsheet ID';

  @override
  String get setSpreadsheetIdHint => 'From the Google Sheets URL';

  @override
  String get setSheetName => 'Sheet Name';

  @override
  String get setSheetNameHint => 'e.g., Spese';

  @override
  String get setNeverSynced => 'Never synced';

  @override
  String setLastSync(String date) {
    return 'Last sync: $date';
  }

  @override
  String get setBankEmailSync => 'Bank email sync';

  @override
  String get setSyncWidibaEmail => 'Sync Widiba emails';

  @override
  String get setSyncWidibaEmailSubtitle =>
      'Create drafts from widiba@widiba.it emails';

  @override
  String get setSearchWindow => 'Search window';

  @override
  String setDaysCount(int count) {
    return '$count days';
  }

  @override
  String get setCustom => 'Custom…';

  @override
  String get setDaysToScan => 'Days to scan';

  @override
  String get setDaysUnit => 'days';

  @override
  String setNewDrafts(int count) {
    return '$count new transactions to review';
  }

  @override
  String setUnreadEmails(int count) {
    return '$count unrecognized emails';
  }

  @override
  String get setNoNewTransactions => 'No new transactions';

  @override
  String setEmailSyncFailed(String error) {
    return 'Email sync failed: $error';
  }

  @override
  String get setBankNotificationSync => 'Bank notification sync';

  @override
  String get setSyncRevolutNotifications => 'Sync Revolut notifications';

  @override
  String get setSyncRevolutNotificationsSubtitle =>
      'Create drafts from Revolut push notifications';

  @override
  String get setNotificationAccess => 'Notification access';

  @override
  String get setNotificationAccessBody =>
      'To read Revolut notifications, Budgetti needs access to system notifications. Open settings?';

  @override
  String get setLater => 'Later';

  @override
  String get setOpenSettings => 'Open settings';

  @override
  String get setGranted => 'Granted';

  @override
  String get setNotGranted => 'Not granted — tap to open settings';

  @override
  String get setReadNotificationsNow => 'Read notifications now';

  @override
  String setUnreadNotifications(int count) {
    return '$count unrecognized notifications';
  }

  @override
  String get setNoNewRevolutNotifications => 'No new Revolut notifications';

  @override
  String get setNotificationAccessMissing => 'Notification access not granted';

  @override
  String setNotificationReadFailed(String error) {
    return 'Reading notifications failed: $error';
  }

  @override
  String get setImportRevolutStatement => 'Import Revolut statement';

  @override
  String get setImportRevolutStatementSubtitle =>
      'From CSV — creates drafts to review, skips duplicates';

  @override
  String setCountToReview(int count) {
    return '$count to review';
  }

  @override
  String setCountAlreadyPresent(int count) {
    return '$count already present';
  }

  @override
  String setCountUnreadableRows(int count) {
    return '$count unreadable rows';
  }

  @override
  String get setNoTransactionsInFile => 'No transactions found in the file';

  @override
  String get setReview => 'Review';

  @override
  String setStatementImportFailed(String error) {
    return 'Statement import failed: $error';
  }

  @override
  String get setAutoBackup => 'Auto Backup';

  @override
  String get setAutoBackupToggle => 'Automatic backup';

  @override
  String get setAutoBackupToggleSubtitle =>
      'Daily local backup (cloud if connected)';

  @override
  String get setBackupTime => 'Backup time';

  @override
  String get setBackupFolder => 'Backup folder';

  @override
  String get setDefaultBackupFolder => 'Default (Internal)';

  @override
  String get setDataManagement => 'Data Management';

  @override
  String get setExportBackup => 'Export backup (JSON)';

  @override
  String get setExportBackupSubtitle => 'Local backup file';

  @override
  String get setImportBackup => 'Import backup (JSON)';

  @override
  String get setImportBackupSubtitle => 'Restore from local file';

  @override
  String get setImportBackupTitle => 'Import Backup';

  @override
  String get setImportBackupBody =>
      'This will REPLACE all your current data. This action cannot be undone.';

  @override
  String get setImport => 'Import';

  @override
  String get statsTitle => 'Stats';

  @override
  String statsError(String err) {
    return 'Error: $err';
  }

  @override
  String get statsDistribution => 'Distribution';

  @override
  String get statsTrends => 'Trends';

  @override
  String get statsBreakdown => 'Breakdown';

  @override
  String get statsLedgerMonthly => 'Ledger · Monthly';

  @override
  String get statsCategories => 'Categories';

  @override
  String get statsNoTagsHint => 'No tagged expenses in this period.';

  @override
  String get statsNoActivity => 'No activity';

  @override
  String statsNothingRecorded(String label) {
    return 'Nothing recorded for $label.';
  }

  @override
  String get statsTryAnotherPeriod =>
      'Try another period from the filters above.';

  @override
  String get statsTrend12Months => '12-month trend';

  @override
  String get statsTransactions => 'Transactions';

  @override
  String statsNoTransactionsIn(String label) {
    return 'No transactions in $label.';
  }

  @override
  String statsNothingRecordedCategory(String label) {
    return 'Nothing recorded for this category in $label.';
  }

  @override
  String get statsScopeExpenses => 'Expenses';

  @override
  String get statsScopeIncome => 'Income';

  @override
  String get statsMonth => 'Month';

  @override
  String get statsYear => 'Year';

  @override
  String get statsTotalSpent => 'Total spent';

  @override
  String get statsTotalEarned => 'Total earned';

  @override
  String get statsNetActivity => 'Net activity';

  @override
  String get statsDailyAvg => 'Daily avg';

  @override
  String get statsNetFlow => 'Net flow';

  @override
  String get statsPredicted => 'Predicted';

  @override
  String get statsSavings => 'Savings';

  @override
  String get statsMonthlyBudget => 'Monthly budget';

  @override
  String statsOver(String amount) {
    return '+$amount over';
  }

  @override
  String statsLeft(String amount) {
    return '$amount left';
  }

  @override
  String statsMore(int count) {
    return '+$count more';
  }

  @override
  String get statsMonthlyAvg => 'Monthly avg';

  @override
  String get statsLargest => 'Largest';

  @override
  String get statsNoTrendData => 'No trend data';

  @override
  String get statsEarned => 'Earned';

  @override
  String get statsSpent => 'Spent';

  @override
  String statsPctOf(String pct) {
    return '$pct% of total';
  }

  @override
  String get txActivity => 'Activity';

  @override
  String get txAllTime => 'All Time';

  @override
  String get txAllWallets => 'All Wallets';

  @override
  String get txAlreadyInAccount => 'Already in the account';

  @override
  String get txApplyFilters => 'Apply Filters';

  @override
  String get txApprove => 'Approve';

  @override
  String get txBetweenYourWallets => 'Between your wallets';

  @override
  String get txCategories => 'Categories';

  @override
  String get txCredit => 'Credit';

  @override
  String get txCustom => 'Custom';

  @override
  String get txDateRange => 'Date range';

  @override
  String txDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Are you sure you want to delete $count items?',
      one: 'Are you sure you want to delete 1 item?',
    );
    return '$_temp0';
  }

  @override
  String get txDeleteTransactionsTitle => 'Delete Transactions?';

  @override
  String get txDetails => 'Details';

  @override
  String get txDestinationWallet => 'Destination wallet';

  @override
  String get txEditExpense => 'Edit expense';

  @override
  String get txEditIncome => 'Edit income';

  @override
  String get txEditTransfer => 'Edit transfer';

  @override
  String get txEmail => 'Email';

  @override
  String get txEnterAmount => 'Enter amount';

  @override
  String get txEnterDescription => 'Enter description';

  @override
  String txError(String error) {
    return 'Error: $error';
  }

  @override
  String txErrorLoadingAccounts(String error) {
    return 'Error loading accounts: $error';
  }

  @override
  String txErrorLoadingCategories(String error) {
    return 'Error loading categories: $error';
  }

  @override
  String txErrorLoadingTags(String error) {
    return 'Error loading tags: $error';
  }

  @override
  String get txExternalOutflow => 'Money going out';

  @override
  String get txFastCategorization => 'Fast Categorization';

  @override
  String get txFilterByWallet => 'Filter by Wallet';

  @override
  String get txFilters => 'Filters';

  @override
  String get txFrom => 'From';

  @override
  String get txFromEmail => 'From email';

  @override
  String get txIgnore => 'Ignore';

  @override
  String get txInstallment => 'Installment';

  @override
  String txInstallmentOption(String amount, int count, int paid) {
    return '$amount × $count · $paid due so far';
  }

  @override
  String get txInvalidAmount => 'Invalid';

  @override
  String get txIsSameExpense => 'Is this the same expense?';

  @override
  String get txLast30Days => 'Last 30 Days';

  @override
  String get txLast7Days => 'Last 7 Days';

  @override
  String get txLedger => 'Ledger';

  @override
  String get txMovements => 'Movements';

  @override
  String get txMovementUndecided => 'Movement — to decide';

  @override
  String get txNewExpense => 'New expense';

  @override
  String get txNewIncome => 'New income';

  @override
  String get txNewTransfer => 'New transfer';

  @override
  String get txNoActivity => 'No activity';

  @override
  String get txNoContent => '(no content)';

  @override
  String get txNoDifferent => 'No, it\'s different';

  @override
  String get txNoTransactionsPeriod => 'No transactions in this period';

  @override
  String get txNoTransactionsToReview => 'No transactions to review';

  @override
  String get txNoWalletSelected => 'No wallet selected';

  @override
  String get txNotARate => 'Not a rate';

  @override
  String get txNote => 'Note';

  @override
  String get txNoteHint => 'What was this for?';

  @override
  String get txNotification => 'Notification';

  @override
  String txOcrError(String error) {
    return 'OCR Error: $error';
  }

  @override
  String get txPayment => 'Payment';

  @override
  String get txPossiblyAlreadyRecorded => 'Possibly already recorded';

  @override
  String get txPleaseSelectOtherWallet =>
      'Please select a different destination wallet';

  @override
  String get txPleaseSelectWallet => 'Please select a wallet';

  @override
  String get txReceiptScanned => 'Receipt scanned';

  @override
  String get txResetAll => 'Reset all';

  @override
  String txReviewBannerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions to review',
      one: '1 transaction to review',
    );
    return '$_temp0';
  }

  @override
  String get txReviewInbox => 'To review';

  @override
  String get txScan => 'Scan';

  @override
  String get txSelect => 'Select';

  @override
  String get txSelectCategory => 'Select Category';

  @override
  String get txSelectDestination => 'Select destination';

  @override
  String get txSelectFromAccount => 'Select From Account';

  @override
  String get txSelectFromWallet => 'Select From Wallet';

  @override
  String get txSelectSource => 'Select source';

  @override
  String get txSelectToAccount => 'Select To Account';

  @override
  String get txSelectToWallet => 'Select To Wallet';

  @override
  String get txSelectWallet => 'Select wallet';

  @override
  String txSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get txSepaUndecided => 'SEPA transfer — to decide';

  @override
  String get txSourceWallet => 'Source wallet';

  @override
  String get txSwipeNext => 'Swipe for next transaction';

  @override
  String get txTo => 'To';

  @override
  String get txTransferDetails => 'Transfer Details';

  @override
  String get txTransactionAdded => 'Transaction added';

  @override
  String get txTransactionUpdated => 'Transaction updated';

  @override
  String txUnrecognizedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unrecognized messages',
      one: '1 unrecognized message',
    );
    return '$_temp0';
  }

  @override
  String get txUnrecognizedMessages => 'Unrecognized messages';

  @override
  String txUnreadableMessage(String kind, String source, String date) {
    return '$kind from $source on $date — couldn\'t read it';
  }

  @override
  String get txUpdate => 'Update';

  @override
  String get txWhatKindOfTransfer => 'What kind of transfer is this?';

  @override
  String get txYesSame => 'Yes, it\'s the same';

  @override
  String get txYouReceived => 'You received';

  @override
  String get txYouSpent => 'You spent';

  @override
  String get txYouTransferred => 'You transferred';
}
