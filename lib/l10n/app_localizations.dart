import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get commonIncome;

  /// No description provided for @commonExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get commonExpense;

  /// No description provided for @commonTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get commonTransfer;

  /// No description provided for @commonDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get commonDate;

  /// No description provided for @commonCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get commonCategory;

  /// No description provided for @commonWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get commonWallet;

  /// No description provided for @commonTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get commonTags;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get commonNoData;

  /// No description provided for @commonSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get commonSystem;

  /// No description provided for @authConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get authConnectionError;

  /// No description provided for @authProfileMissing.
  ///
  /// In en, this message translates to:
  /// **'Profile missing (Error)'**
  String get authProfileMissing;

  /// No description provided for @authDetailedError.
  ///
  /// In en, this message translates to:
  /// **'Detailed error: {error}'**
  String authDetailedError(String error);

  /// No description provided for @authLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get authLoginFailed;

  /// No description provided for @authCannotReachServer.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach server. Check the URL in Settings > Integrations.'**
  String get authCannotReachServer;

  /// No description provided for @authLoginTagline.
  ///
  /// In en, this message translates to:
  /// **'Manage your finances like a pro'**
  String get authLoginTagline;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get authLogIn;

  /// No description provided for @authSetServer.
  ///
  /// In en, this message translates to:
  /// **'Set server'**
  String get authSetServer;

  /// No description provided for @authWhoAreYou.
  ///
  /// In en, this message translates to:
  /// **'Who are you?'**
  String get authWhoAreYou;

  /// No description provided for @authChooseUsername.
  ///
  /// In en, this message translates to:
  /// **'Choose a Username'**
  String get authChooseUsername;

  /// No description provided for @authUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what to call you in the app.'**
  String get authUsernameHint;

  /// No description provided for @authUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get authUsername;

  /// No description provided for @authUsernameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least {min} characters'**
  String authUsernameMinLength(int min);

  /// No description provided for @authGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get authGetStarted;

  /// No description provided for @authSyncSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up sync'**
  String get authSyncSetupTitle;

  /// No description provided for @authSyncSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How should this device and the server line up?'**
  String get authSyncSetupSubtitle;

  /// No description provided for @authCheckingServer.
  ///
  /// In en, this message translates to:
  /// **'Checking the server…'**
  String get authCheckingServer;

  /// No description provided for @authServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server.'**
  String get authServerUnreachable;

  /// No description provided for @authServerHasData.
  ///
  /// In en, this message translates to:
  /// **'The server already has data for this account ({count} transactions).'**
  String authServerHasData(int count);

  /// No description provided for @authServerNoData.
  ///
  /// In en, this message translates to:
  /// **'The server has no data for this account yet.'**
  String get authServerNoData;

  /// No description provided for @authRetrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check the server connection again'**
  String get authRetrySubtitle;

  /// No description provided for @authUseServerData.
  ///
  /// In en, this message translates to:
  /// **'Use the server\'s data'**
  String get authUseServerData;

  /// No description provided for @authUseServerDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download everything to this device ({count} transactions)'**
  String authUseServerDataSubtitle(int count);

  /// No description provided for @authUploadDeviceData.
  ///
  /// In en, this message translates to:
  /// **'Upload this device\'s data'**
  String get authUploadDeviceData;

  /// No description provided for @authUploadDeviceDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Push all local data to the server ({count} transactions)'**
  String authUploadDeviceDataSubtitle(int count);

  /// No description provided for @authRestoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore a backup file'**
  String get authRestoreBackup;

  /// No description provided for @authRestoreBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import a Budgetti JSON backup, then upload it'**
  String get authRestoreBackupSubtitle;

  /// No description provided for @authContinueWithoutSync.
  ///
  /// In en, this message translates to:
  /// **'Continue without syncing'**
  String get authContinueWithoutSync;

  /// No description provided for @authContinueWithoutSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep local and server data as they are for now'**
  String get authContinueWithoutSyncSubtitle;

  /// No description provided for @authActionDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get authActionDownload;

  /// No description provided for @authActionUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get authActionUpload;

  /// No description provided for @authActionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get authActionRestore;

  /// No description provided for @authActionFailed.
  ///
  /// In en, this message translates to:
  /// **'{action} failed: {error}'**
  String authActionFailed(String action, String error);

  /// No description provided for @authProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get authProfileTitle;

  /// No description provided for @authUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get authUser;

  /// No description provided for @authAvatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated'**
  String get authAvatarUpdated;

  /// No description provided for @authAvatarSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving image: {error}'**
  String authAvatarSaveError(String error);

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get authSignOut;

  /// No description provided for @authNavDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get authNavDashboard;

  /// No description provided for @authNavHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get authNavHistory;

  /// No description provided for @authNavStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get authNavStats;

  /// No description provided for @authNavSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get authNavSettings;

  /// No description provided for @dashConnectivityIssue.
  ///
  /// In en, this message translates to:
  /// **'Connectivity Issue'**
  String get dashConnectivityIssue;

  /// No description provided for @dashConnectivityMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the server. Please check your connection.'**
  String get dashConnectivityMessage;

  /// No description provided for @dashSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync Failed'**
  String get dashSyncFailed;

  /// No description provided for @dashNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts found'**
  String get dashNoAccounts;

  /// No description provided for @dashErrorCalculatingStats.
  ///
  /// In en, this message translates to:
  /// **'Error calculating stats'**
  String get dashErrorCalculatingStats;

  /// No description provided for @dashSetUpBudgets.
  ///
  /// In en, this message translates to:
  /// **'Set up budgets'**
  String get dashSetUpBudgets;

  /// No description provided for @dashSetUpBudgetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track category spending each month'**
  String get dashSetUpBudgetsSubtitle;

  /// No description provided for @dashMonthlyBudgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget'**
  String get dashMonthlyBudgetLabel;

  /// No description provided for @dashCategoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get dashCategoriesLabel;

  /// No description provided for @dashTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get dashTotalBalance;

  /// No description provided for @dashTrend30d.
  ///
  /// In en, this message translates to:
  /// **'30d'**
  String get dashTrend30d;

  /// No description provided for @dashWalletsLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get dashWalletsLabel;

  /// No description provided for @dashWalletsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load wallets'**
  String get dashWalletsLoadError;

  /// No description provided for @dashNoWallets.
  ///
  /// In en, this message translates to:
  /// **'No wallets yet'**
  String get dashNoWallets;

  /// No description provided for @dashWalletsMore.
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String dashWalletsMore(int count);

  /// No description provided for @dashStatIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get dashStatIn;

  /// No description provided for @dashStatOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get dashStatOut;

  /// No description provided for @dashStatNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get dashStatNet;

  /// No description provided for @dashStillOwedLabel.
  ///
  /// In en, this message translates to:
  /// **'Still owed'**
  String get dashStillOwedLabel;

  /// No description provided for @dashPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount} / month'**
  String dashPerMonth(String amount);

  /// No description provided for @dashPlansLabel.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get dashPlansLabel;

  /// No description provided for @dashMorePlans.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String dashMorePlans(int count);

  /// No description provided for @dashNextDue.
  ///
  /// In en, this message translates to:
  /// **'Next {date}'**
  String dashNextDue(String date);

  /// No description provided for @dashRecentLabel.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get dashRecentLabel;

  /// No description provided for @dashLastCount.
  ///
  /// In en, this message translates to:
  /// **'Last {count}'**
  String dashLastCount(int count);

  /// No description provided for @dashAllLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get dashAllLabel;

  /// No description provided for @dashNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get dashNoTransactions;

  /// No description provided for @dashYesterdayShort.
  ///
  /// In en, this message translates to:
  /// **'YDA'**
  String get dashYesterdayShort;

  /// No description provided for @dashDaysAgoShort.
  ///
  /// In en, this message translates to:
  /// **'{days}D'**
  String dashDaysAgoShort(int days);

  /// No description provided for @budgetScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgetScreenTitle;

  /// No description provided for @budgetSortUtilization.
  ///
  /// In en, this message translates to:
  /// **'Utilization'**
  String get budgetSortUtilization;

  /// No description provided for @budgetSortAlphabetical.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get budgetSortAlphabetical;

  /// No description provided for @budgetSortLimitHighLow.
  ///
  /// In en, this message translates to:
  /// **'Limit: High to Low'**
  String get budgetSortLimitHighLow;

  /// No description provided for @budgetSortLimitLowHigh.
  ///
  /// In en, this message translates to:
  /// **'Limit: Low to High'**
  String get budgetSortLimitLowHigh;

  /// No description provided for @budgetTracked.
  ///
  /// In en, this message translates to:
  /// **'TRACKED'**
  String get budgetTracked;

  /// No description provided for @budgetSectionUnset.
  ///
  /// In en, this message translates to:
  /// **'UNSET'**
  String get budgetSectionUnset;

  /// No description provided for @budgetNoCategories.
  ///
  /// In en, this message translates to:
  /// **'NO CATEGORIES'**
  String get budgetNoCategories;

  /// No description provided for @budgetEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add expense categories first to start tracking budgets.'**
  String get budgetEmptyHint;

  /// No description provided for @budgetErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'ERROR'**
  String get budgetErrorLabel;

  /// No description provided for @budgetUpdated.
  ///
  /// In en, this message translates to:
  /// **'Budget updated'**
  String get budgetUpdated;

  /// No description provided for @budgetSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving budget: {error}'**
  String budgetSaveError(String error);

  /// No description provided for @budgetMonthlyLimit.
  ///
  /// In en, this message translates to:
  /// **'MONTHLY LIMIT'**
  String get budgetMonthlyLimit;

  /// No description provided for @budgetAmountHint.
  ///
  /// In en, this message translates to:
  /// **'0.00'**
  String get budgetAmountHint;

  /// No description provided for @budgetEnterLimit.
  ///
  /// In en, this message translates to:
  /// **'Enter limit'**
  String get budgetEnterLimit;

  /// No description provided for @budgetInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get budgetInvalid;

  /// No description provided for @budgetMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Must be positive'**
  String get budgetMustBePositive;

  /// No description provided for @budgetClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get budgetClear;

  /// No description provided for @budgetUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get budgetUpdate;

  /// No description provided for @budgetCleared.
  ///
  /// In en, this message translates to:
  /// **'Budget cleared'**
  String get budgetCleared;

  /// No description provided for @budgetUtilizationOf.
  ///
  /// In en, this message translates to:
  /// **'UTILIZATION  ·  {month}'**
  String budgetUtilizationOf(String month);

  /// No description provided for @budgetNoBudgetsSet.
  ///
  /// In en, this message translates to:
  /// **'NO BUDGETS SET  ·  {month}'**
  String budgetNoBudgetsSet(String month);

  /// No description provided for @budgetTapToSet.
  ///
  /// In en, this message translates to:
  /// **'Tap a category below to set a limit.'**
  String get budgetTapToSet;

  /// No description provided for @budgetSpent.
  ///
  /// In en, this message translates to:
  /// **'SPENT'**
  String get budgetSpent;

  /// No description provided for @budgetBudgeted.
  ///
  /// In en, this message translates to:
  /// **'BUDGETED'**
  String get budgetBudgeted;

  /// No description provided for @budgetRemaining.
  ///
  /// In en, this message translates to:
  /// **'REMAINING'**
  String get budgetRemaining;

  /// No description provided for @budgetOver.
  ///
  /// In en, this message translates to:
  /// **'OVER'**
  String get budgetOver;

  /// No description provided for @budgetNoLimit.
  ///
  /// In en, this message translates to:
  /// **'NO LIMIT · TAP TO SET'**
  String get budgetNoLimit;

  /// No description provided for @budgetSet.
  ///
  /// In en, this message translates to:
  /// **'SET'**
  String get budgetSet;

  /// No description provided for @instScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Installments'**
  String get instScreenTitle;

  /// No description provided for @instActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get instActive;

  /// No description provided for @instSettled.
  ///
  /// In en, this message translates to:
  /// **'SETTLED'**
  String get instSettled;

  /// No description provided for @instStillOwed.
  ///
  /// In en, this message translates to:
  /// **'STILL OWED'**
  String get instStillOwed;

  /// No description provided for @instMonthlyActive.
  ///
  /// In en, this message translates to:
  /// **'{amount} / month · {count} active'**
  String instMonthlyActive(String amount, int count);

  /// No description provided for @instDeletePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete plan?'**
  String get instDeletePlanTitle;

  /// No description provided for @instDeletePlanBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed.'**
  String instDeletePlanBody(String name);

  /// No description provided for @instPerMo.
  ///
  /// In en, this message translates to:
  /// **'{amount}/mo'**
  String instPerMo(String amount);

  /// No description provided for @instPaidOf.
  ///
  /// In en, this message translates to:
  /// **'{paid}/{total} paid'**
  String instPaidOf(int paid, int total);

  /// No description provided for @instLinkedCount.
  ///
  /// In en, this message translates to:
  /// **'· {count} linked'**
  String instLinkedCount(int count);

  /// No description provided for @instSettledLabel.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get instSettledLabel;

  /// No description provided for @instRemainingNext.
  ///
  /// In en, this message translates to:
  /// **'{amount} left · next {date}'**
  String instRemainingNext(String amount, String date);

  /// No description provided for @instNoPlans.
  ///
  /// In en, this message translates to:
  /// **'NO PLANS'**
  String get instNoPlans;

  /// No description provided for @instEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add a purchase you are paying in monthly rates and this tracks what you still owe.'**
  String get instEmptyHint;

  /// No description provided for @instAddPlan.
  ///
  /// In en, this message translates to:
  /// **'Add a plan'**
  String get instAddPlan;

  /// No description provided for @instSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving plan: {error}'**
  String instSaveError(String error);

  /// No description provided for @instNewPlan.
  ///
  /// In en, this message translates to:
  /// **'NEW PLAN'**
  String get instNewPlan;

  /// No description provided for @instEditPlan.
  ///
  /// In en, this message translates to:
  /// **'EDIT PLAN'**
  String get instEditPlan;

  /// No description provided for @instWhatFor.
  ///
  /// In en, this message translates to:
  /// **'What is it for'**
  String get instWhatFor;

  /// No description provided for @instWhatForHint.
  ///
  /// In en, this message translates to:
  /// **'Sofa, laptop, holiday…'**
  String get instWhatForHint;

  /// No description provided for @instRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get instRequired;

  /// No description provided for @instTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get instTotal;

  /// No description provided for @instInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get instInvalid;

  /// No description provided for @instMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Must be positive'**
  String get instMustBePositive;

  /// No description provided for @instAtLeast1.
  ///
  /// In en, this message translates to:
  /// **'At least 1'**
  String get instAtLeast1;

  /// No description provided for @instRatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Rates'**
  String get instRatesLabel;

  /// No description provided for @instPerRateHint.
  ///
  /// In en, this message translates to:
  /// **'Monthly rate appears here'**
  String get instPerRateHint;

  /// No description provided for @instPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount} / month'**
  String instPerMonth(String amount);

  /// No description provided for @instFirstRateOn.
  ///
  /// In en, this message translates to:
  /// **'First rate on'**
  String get instFirstRateOn;

  /// No description provided for @instCategoryOptional.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get instCategoryOptional;

  /// No description provided for @instWalletOptional.
  ///
  /// In en, this message translates to:
  /// **'Wallet (optional)'**
  String get instWalletOptional;

  /// No description provided for @instUpdatePlan.
  ///
  /// In en, this message translates to:
  /// **'Update plan'**
  String get instUpdatePlan;

  /// No description provided for @instLinkedPaymentsOf.
  ///
  /// In en, this message translates to:
  /// **'LINKED PAYMENTS · {linked}/{due}'**
  String instLinkedPaymentsOf(int linked, int due);

  /// No description provided for @instAllAccounted.
  ///
  /// In en, this message translates to:
  /// **'Every rate due so far is accounted for.'**
  String get instAllAccounted;

  /// No description provided for @instMissingRates.
  ///
  /// In en, this message translates to:
  /// **'{missing} of the {due} rates due so far have no transaction attached.'**
  String instMissingRates(int missing, int due);

  /// No description provided for @instUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get instUnlink;

  /// No description provided for @instNoCandidates.
  ///
  /// In en, this message translates to:
  /// **'No unlinked expenses to attach.'**
  String get instNoCandidates;

  /// No description provided for @instAttachPayment.
  ///
  /// In en, this message translates to:
  /// **'Attach a payment'**
  String get instAttachPayment;

  /// No description provided for @importSelectWalletError.
  ///
  /// In en, this message translates to:
  /// **'Please select a wallet'**
  String get importSelectWalletError;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully imported {count} transactions'**
  String importSuccess(int count);

  /// No description provided for @importError.
  ///
  /// In en, this message translates to:
  /// **'Error importing: {error}'**
  String importError(String error);

  /// No description provided for @importSelectWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Wallet'**
  String get importSelectWalletTitle;

  /// No description provided for @importPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Preview'**
  String get importPreviewTitle;

  /// No description provided for @importToWallet.
  ///
  /// In en, this message translates to:
  /// **'Import to Wallet'**
  String get importToWallet;

  /// No description provided for @importFound.
  ///
  /// In en, this message translates to:
  /// **'Transactions found: {count}'**
  String importFound(int count);

  /// No description provided for @importTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String importTotal(String amount);

  /// No description provided for @importConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Import'**
  String get importConfirm;

  /// No description provided for @chartNoDataYear.
  ///
  /// In en, this message translates to:
  /// **'No data available for this year'**
  String get chartNoDataYear;

  /// No description provided for @chartWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String chartWeekOf(String date);

  /// No description provided for @chartExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get chartExpenses;

  /// No description provided for @chartIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get chartIncome;

  /// No description provided for @chartWeekShort.
  ///
  /// In en, this message translates to:
  /// **'W{week}'**
  String chartWeekShort(int week);

  /// No description provided for @uiSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get uiSelectCategory;

  /// No description provided for @uiNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
  String get uiNoCategories;

  /// No description provided for @uiSelectWallet.
  ///
  /// In en, this message translates to:
  /// **'Select Wallet'**
  String get uiSelectWallet;

  /// No description provided for @uiAllWallets.
  ///
  /// In en, this message translates to:
  /// **'All Wallets'**
  String get uiAllWallets;

  /// No description provided for @notifBackupDone.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup completed successfully.'**
  String get notifBackupDone;

  /// No description provided for @notifBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup failed. Check settings.'**
  String get notifBackupFailed;

  /// No description provided for @notifBudgetAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget Alert'**
  String get notifBudgetAlertTitle;

  /// No description provided for @notifBudgetReached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your budget for {category}!'**
  String notifBudgetReached(String category);

  /// No description provided for @notifBudgetUsedPct.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used {percent}% of your {category} budget.'**
  String notifBudgetUsedPct(String percent, String category);

  /// No description provided for @notifDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Track your expenses'**
  String get notifDailyTitle;

  /// No description provided for @notifDailyBody.
  ///
  /// In en, this message translates to:
  /// **'Don\'t forget to log your spending for today!'**
  String get notifDailyBody;

  /// No description provided for @notifBackupProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup in progress...'**
  String get notifBackupProgressTitle;

  /// No description provided for @notifBackupSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup Successful'**
  String get notifBackupSuccessTitle;

  /// No description provided for @notifBackupFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup Failed'**
  String get notifBackupFailedTitle;

  /// No description provided for @notifBackupProgressBody.
  ///
  /// In en, this message translates to:
  /// **'Saving your data safely.'**
  String get notifBackupProgressBody;

  /// No description provided for @notifBackupSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your data has been backed up.'**
  String get notifBackupSuccessBody;

  /// No description provided for @notifBackupErrorBody.
  ///
  /// In en, this message translates to:
  /// **'There was an error during backup.'**
  String get notifBackupErrorBody;

  /// No description provided for @notifEmailIncome.
  ///
  /// In en, this message translates to:
  /// **'Credit received'**
  String get notifEmailIncome;

  /// No description provided for @notifEmailReview.
  ///
  /// In en, this message translates to:
  /// **'Transfer to review'**
  String get notifEmailReview;

  /// No description provided for @notifEmailExpense.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get notifEmailExpense;

  /// No description provided for @setSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get setSettings;

  /// No description provided for @setAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get setAccount;

  /// No description provided for @setProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get setProfile;

  /// No description provided for @setAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get setAppearance;

  /// No description provided for @setAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Palette, theme, effects'**
  String get setAppearanceSubtitle;

  /// No description provided for @setPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get setPreferences;

  /// No description provided for @setPreferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Currency, scanner, notifications'**
  String get setPreferencesSubtitle;

  /// No description provided for @setIntegrationsBackup.
  ///
  /// In en, this message translates to:
  /// **'Integrations & Backup'**
  String get setIntegrationsBackup;

  /// No description provided for @setIntegrationsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drive, Sheets, auto backup'**
  String get setIntegrationsBackupSubtitle;

  /// No description provided for @setData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get setData;

  /// No description provided for @setAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get setAbout;

  /// No description provided for @setSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get setSourceCode;

  /// No description provided for @setSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get setSignOut;

  /// No description provided for @setImportQuicken.
  ///
  /// In en, this message translates to:
  /// **'Import Quicken (QIF)'**
  String get setImportQuicken;

  /// No description provided for @setImportQuickenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Load transactions from a .qif file'**
  String get setImportQuickenSubtitle;

  /// No description provided for @setSelectQifFile.
  ///
  /// In en, this message translates to:
  /// **'Please select a .qif file'**
  String get setSelectQifFile;

  /// No description provided for @setLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get setLanguage;

  /// No description provided for @setPalette.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get setPalette;

  /// No description provided for @setBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get setBrightness;

  /// No description provided for @setThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get setThemeLight;

  /// No description provided for @setThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get setThemeDark;

  /// No description provided for @setEffects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get setEffects;

  /// No description provided for @setAmoledBlack.
  ///
  /// In en, this message translates to:
  /// **'AMOLED black'**
  String get setAmoledBlack;

  /// No description provided for @setAmoledBlackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pure black background in dark mode'**
  String get setAmoledBlackSubtitle;

  /// No description provided for @setLiquidGlass.
  ///
  /// In en, this message translates to:
  /// **'Liquid glass'**
  String get setLiquidGlass;

  /// No description provided for @setLiquidGlassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Frosted blur on nav bar and sheets'**
  String get setLiquidGlassSubtitle;

  /// No description provided for @setCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get setCategories;

  /// No description provided for @setTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get setTags;

  /// No description provided for @setWallets.
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get setWallets;

  /// No description provided for @setNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get setNoCategories;

  /// No description provided for @setCreateFirstCategory.
  ///
  /// In en, this message translates to:
  /// **'Create your first category'**
  String get setCreateFirstCategory;

  /// No description provided for @setNoTags.
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get setNoTags;

  /// No description provided for @setNoWallets.
  ///
  /// In en, this message translates to:
  /// **'No wallets yet'**
  String get setNoWallets;

  /// No description provided for @setExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get setExpenses;

  /// No description provided for @setIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get setIncome;

  /// No description provided for @setRestoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore Defaults'**
  String get setRestoreDefaults;

  /// No description provided for @setRestoreDefaultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Defaults?'**
  String get setRestoreDefaultsTitle;

  /// No description provided for @setRestoreCategoriesBody.
  ///
  /// In en, this message translates to:
  /// **'This will restore default categories if they were deleted or modified. Your custom categories will not be affected.'**
  String get setRestoreCategoriesBody;

  /// No description provided for @setRestoreTagsBody.
  ///
  /// In en, this message translates to:
  /// **'This will restore default tags if they were deleted or modified. Your custom tags will not be affected.'**
  String get setRestoreTagsBody;

  /// No description provided for @setRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get setRestore;

  /// No description provided for @setCategoriesRestored.
  ///
  /// In en, this message translates to:
  /// **'Default categories restored'**
  String get setCategoriesRestored;

  /// No description provided for @setTagsRestored.
  ///
  /// In en, this message translates to:
  /// **'Default tags restored'**
  String get setTagsRestored;

  /// No description provided for @setDeleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Category?'**
  String get setDeleteCategoryTitle;

  /// No description provided for @setDeleteTagTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Tag'**
  String get setDeleteTagTitle;

  /// No description provided for @setDeleteWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get setDeleteWalletTitle;

  /// No description provided for @setDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \'{name}\'?'**
  String setDeleteConfirmBody(String name);

  /// No description provided for @setDeleteWalletBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \'{name}\'? This won\'t delete transactions but they might become unassigned.'**
  String setDeleteWalletBody(String name);

  /// No description provided for @setErrorWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String setErrorWithDetails(String error);

  /// No description provided for @setNewCategory.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get setNewCategory;

  /// No description provided for @setEditCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get setEditCategory;

  /// No description provided for @setFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get setFieldName;

  /// No description provided for @setFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get setFieldType;

  /// No description provided for @setFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get setFieldDescription;

  /// No description provided for @setFieldSelectIcon.
  ///
  /// In en, this message translates to:
  /// **'Select icon'**
  String get setFieldSelectIcon;

  /// No description provided for @setCategoryNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Shopping, Rent...'**
  String get setCategoryNameHint;

  /// No description provided for @setCategoryDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a short note about this category...'**
  String get setCategoryDescriptionHint;

  /// No description provided for @setSaveCategory.
  ///
  /// In en, this message translates to:
  /// **'Save Category'**
  String get setSaveCategory;

  /// No description provided for @setSelectColor.
  ///
  /// In en, this message translates to:
  /// **'Select Color'**
  String get setSelectColor;

  /// No description provided for @setNewTag.
  ///
  /// In en, this message translates to:
  /// **'New Tag'**
  String get setNewTag;

  /// No description provided for @setEditTag.
  ///
  /// In en, this message translates to:
  /// **'Edit Tag'**
  String get setEditTag;

  /// No description provided for @setTagName.
  ///
  /// In en, this message translates to:
  /// **'Tag Name'**
  String get setTagName;

  /// No description provided for @setColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get setColor;

  /// No description provided for @setCreateTag.
  ///
  /// In en, this message translates to:
  /// **'Create Tag'**
  String get setCreateTag;

  /// No description provided for @setUpdateTag.
  ///
  /// In en, this message translates to:
  /// **'Update Tag'**
  String get setUpdateTag;

  /// No description provided for @setNewWallet.
  ///
  /// In en, this message translates to:
  /// **'New Account'**
  String get setNewWallet;

  /// No description provided for @setEditWallet.
  ///
  /// In en, this message translates to:
  /// **'Edit Account'**
  String get setEditWallet;

  /// No description provided for @setWalletNameHint.
  ///
  /// In en, this message translates to:
  /// **'Account Name (e.g. PayPal, Bank)'**
  String get setWalletNameHint;

  /// No description provided for @setInitialAmount.
  ///
  /// In en, this message translates to:
  /// **'Initial Amount'**
  String get setInitialAmount;

  /// No description provided for @setStartingDate.
  ///
  /// In en, this message translates to:
  /// **'Starting Date'**
  String get setStartingDate;

  /// No description provided for @setAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'All transactions'**
  String get setAllTransactions;

  /// No description provided for @setSetAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setSetAsDefault;

  /// No description provided for @setCreateWallet.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get setCreateWallet;

  /// No description provided for @setUpdateWallet.
  ///
  /// In en, this message translates to:
  /// **'Update Account'**
  String get setUpdateWallet;

  /// No description provided for @setWalletSince.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String setWalletSince(String date);

  /// No description provided for @setGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get setGeneral;

  /// No description provided for @setCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get setCurrency;

  /// No description provided for @setSelectCurrency.
  ///
  /// In en, this message translates to:
  /// **'Select Currency'**
  String get setSelectCurrency;

  /// No description provided for @setCurrencyEur.
  ///
  /// In en, this message translates to:
  /// **'Euro'**
  String get setCurrencyEur;

  /// No description provided for @setCurrencyUsd.
  ///
  /// In en, this message translates to:
  /// **'US Dollar'**
  String get setCurrencyUsd;

  /// No description provided for @setCurrencyGbp.
  ///
  /// In en, this message translates to:
  /// **'British Pound'**
  String get setCurrencyGbp;

  /// No description provided for @setCurrencyJpy.
  ///
  /// In en, this message translates to:
  /// **'Japanese Yen'**
  String get setCurrencyJpy;

  /// No description provided for @setNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get setNotifications;

  /// No description provided for @setFixPermissions.
  ///
  /// In en, this message translates to:
  /// **'Fix Permissions'**
  String get setFixPermissions;

  /// No description provided for @setFixPermissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to enable notifications'**
  String get setFixPermissionsSubtitle;

  /// No description provided for @setPushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get setPushNotifications;

  /// No description provided for @setPushNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Main system alerts'**
  String get setPushNotificationsSubtitle;

  /// No description provided for @setBudgetAlerts.
  ///
  /// In en, this message translates to:
  /// **'Budget Alerts'**
  String get setBudgetAlerts;

  /// No description provided for @setBudgetAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Limit thresholds'**
  String get setBudgetAlertsSubtitle;

  /// No description provided for @setDailyReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily Reminder'**
  String get setDailyReminder;

  /// No description provided for @setDailyReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manual logging'**
  String get setDailyReminderSubtitle;

  /// No description provided for @setReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder Time'**
  String get setReminderTime;

  /// No description provided for @setIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get setIntegrations;

  /// No description provided for @setCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get setCloudSync;

  /// No description provided for @setServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get setServer;

  /// No description provided for @setNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get setNotConfigured;

  /// No description provided for @setSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get setSyncNow;

  /// No description provided for @setPushEverything.
  ///
  /// In en, this message translates to:
  /// **'Push everything'**
  String get setPushEverything;

  /// No description provided for @setPushEverythingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload all local data (categories, tags, wallets, transactions, budgets) to the server'**
  String get setPushEverythingSubtitle;

  /// No description provided for @setPullEverything.
  ///
  /// In en, this message translates to:
  /// **'Pull everything'**
  String get setPullEverything;

  /// No description provided for @setPullEverythingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download all server data to this device'**
  String get setPullEverythingSubtitle;

  /// No description provided for @setConfigureServerFirst.
  ///
  /// In en, this message translates to:
  /// **'Configure the server URL first'**
  String get setConfigureServerFirst;

  /// No description provided for @setSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String setSyncFailed(String error);

  /// No description provided for @setPbServerTitle.
  ///
  /// In en, this message translates to:
  /// **'PocketBase server'**
  String get setPbServerTitle;

  /// No description provided for @setPbHost.
  ///
  /// In en, this message translates to:
  /// **'Host or IP'**
  String get setPbHost;

  /// No description provided for @setPbPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get setPbPort;

  /// No description provided for @setGoogleDrive.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get setGoogleDrive;

  /// No description provided for @setConnectDrive.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Drive'**
  String get setConnectDrive;

  /// No description provided for @setConnectDriveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup & restore'**
  String get setConnectDriveSubtitle;

  /// No description provided for @setDriveConnected.
  ///
  /// In en, this message translates to:
  /// **'Drive Connected'**
  String get setDriveConnected;

  /// No description provided for @setBackupNow.
  ///
  /// In en, this message translates to:
  /// **'Backup now'**
  String get setBackupNow;

  /// No description provided for @setRestoreFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get setRestoreFromBackup;

  /// No description provided for @setGoogleConnected.
  ///
  /// In en, this message translates to:
  /// **'Successfully connected to Google'**
  String get setGoogleConnected;

  /// No description provided for @setSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed: {error}'**
  String setSignInFailed(String error);

  /// No description provided for @setSignInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled'**
  String get setSignInCancelled;

  /// No description provided for @setBackupDone.
  ///
  /// In en, this message translates to:
  /// **'Backup successful'**
  String get setBackupDone;

  /// No description provided for @setBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {error}'**
  String setBackupFailed(String error);

  /// No description provided for @setNoBackups.
  ///
  /// In en, this message translates to:
  /// **'No backups found'**
  String get setNoBackups;

  /// No description provided for @setSelectBackup.
  ///
  /// In en, this message translates to:
  /// **'Select Backup'**
  String get setSelectBackup;

  /// No description provided for @setUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get setUnknown;

  /// No description provided for @setRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'Restore successful'**
  String get setRestoreDone;

  /// No description provided for @setRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String setRestoreFailed(String error);

  /// No description provided for @setGoogleSheets.
  ///
  /// In en, this message translates to:
  /// **'Google Sheets'**
  String get setGoogleSheets;

  /// No description provided for @setSpreadsheet.
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet'**
  String get setSpreadsheet;

  /// No description provided for @setSheetsConfig.
  ///
  /// In en, this message translates to:
  /// **'Google Sheets Config'**
  String get setSheetsConfig;

  /// No description provided for @setSpreadsheetId.
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet ID'**
  String get setSpreadsheetId;

  /// No description provided for @setSpreadsheetIdHint.
  ///
  /// In en, this message translates to:
  /// **'From the Google Sheets URL'**
  String get setSpreadsheetIdHint;

  /// No description provided for @setSheetName.
  ///
  /// In en, this message translates to:
  /// **'Sheet Name'**
  String get setSheetName;

  /// No description provided for @setSheetNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Spese'**
  String get setSheetNameHint;

  /// No description provided for @setNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get setNeverSynced;

  /// No description provided for @setLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {date}'**
  String setLastSync(String date);

  /// No description provided for @setBankEmailSync.
  ///
  /// In en, this message translates to:
  /// **'Bank email sync'**
  String get setBankEmailSync;

  /// No description provided for @setSyncWidibaEmail.
  ///
  /// In en, this message translates to:
  /// **'Sync Widiba emails'**
  String get setSyncWidibaEmail;

  /// No description provided for @setSyncWidibaEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create drafts from widiba@widiba.it emails'**
  String get setSyncWidibaEmailSubtitle;

  /// No description provided for @setSearchWindow.
  ///
  /// In en, this message translates to:
  /// **'Search window'**
  String get setSearchWindow;

  /// No description provided for @setDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String setDaysCount(int count);

  /// No description provided for @setCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get setCustom;

  /// No description provided for @setDaysToScan.
  ///
  /// In en, this message translates to:
  /// **'Days to scan'**
  String get setDaysToScan;

  /// No description provided for @setDaysUnit.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get setDaysUnit;

  /// No description provided for @setNewDrafts.
  ///
  /// In en, this message translates to:
  /// **'{count} new transactions to review'**
  String setNewDrafts(int count);

  /// No description provided for @setUnreadEmails.
  ///
  /// In en, this message translates to:
  /// **'{count} unrecognized emails'**
  String setUnreadEmails(int count);

  /// No description provided for @setNoNewTransactions.
  ///
  /// In en, this message translates to:
  /// **'No new transactions'**
  String get setNoNewTransactions;

  /// No description provided for @setEmailSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Email sync failed: {error}'**
  String setEmailSyncFailed(String error);

  /// No description provided for @setBankNotificationSync.
  ///
  /// In en, this message translates to:
  /// **'Bank notification sync'**
  String get setBankNotificationSync;

  /// No description provided for @setSyncRevolutNotifications.
  ///
  /// In en, this message translates to:
  /// **'Sync Revolut notifications'**
  String get setSyncRevolutNotifications;

  /// No description provided for @setSyncRevolutNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create drafts from Revolut push notifications'**
  String get setSyncRevolutNotificationsSubtitle;

  /// No description provided for @setNotificationAccess.
  ///
  /// In en, this message translates to:
  /// **'Notification access'**
  String get setNotificationAccess;

  /// No description provided for @setNotificationAccessBody.
  ///
  /// In en, this message translates to:
  /// **'To read Revolut notifications, Budgetti needs access to system notifications. Open settings?'**
  String get setNotificationAccessBody;

  /// No description provided for @setLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get setLater;

  /// No description provided for @setOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get setOpenSettings;

  /// No description provided for @setGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get setGranted;

  /// No description provided for @setNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Not granted — tap to open settings'**
  String get setNotGranted;

  /// No description provided for @setReadNotificationsNow.
  ///
  /// In en, this message translates to:
  /// **'Read notifications now'**
  String get setReadNotificationsNow;

  /// No description provided for @setUnreadNotifications.
  ///
  /// In en, this message translates to:
  /// **'{count} unrecognized notifications'**
  String setUnreadNotifications(int count);

  /// No description provided for @setNoNewRevolutNotifications.
  ///
  /// In en, this message translates to:
  /// **'No new Revolut notifications'**
  String get setNoNewRevolutNotifications;

  /// No description provided for @setNotificationAccessMissing.
  ///
  /// In en, this message translates to:
  /// **'Notification access not granted'**
  String get setNotificationAccessMissing;

  /// No description provided for @setNotificationReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Reading notifications failed: {error}'**
  String setNotificationReadFailed(String error);

  /// No description provided for @setImportRevolutStatement.
  ///
  /// In en, this message translates to:
  /// **'Import Revolut statement'**
  String get setImportRevolutStatement;

  /// No description provided for @setImportRevolutStatementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'From CSV — creates drafts to review, skips duplicates'**
  String get setImportRevolutStatementSubtitle;

  /// No description provided for @setCountToReview.
  ///
  /// In en, this message translates to:
  /// **'{count} to review'**
  String setCountToReview(int count);

  /// No description provided for @setCountAlreadyPresent.
  ///
  /// In en, this message translates to:
  /// **'{count} already present'**
  String setCountAlreadyPresent(int count);

  /// No description provided for @setCountUnreadableRows.
  ///
  /// In en, this message translates to:
  /// **'{count} unreadable rows'**
  String setCountUnreadableRows(int count);

  /// No description provided for @setNoTransactionsInFile.
  ///
  /// In en, this message translates to:
  /// **'No transactions found in the file'**
  String get setNoTransactionsInFile;

  /// No description provided for @setReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get setReview;

  /// No description provided for @setStatementImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Statement import failed: {error}'**
  String setStatementImportFailed(String error);

  /// No description provided for @setAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Auto Backup'**
  String get setAutoBackup;

  /// No description provided for @setAutoBackupToggle.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get setAutoBackupToggle;

  /// No description provided for @setAutoBackupToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Daily local backup (cloud if connected)'**
  String get setAutoBackupToggleSubtitle;

  /// No description provided for @setBackupTime.
  ///
  /// In en, this message translates to:
  /// **'Backup time'**
  String get setBackupTime;

  /// No description provided for @setBackupFolder.
  ///
  /// In en, this message translates to:
  /// **'Backup folder'**
  String get setBackupFolder;

  /// No description provided for @setDefaultBackupFolder.
  ///
  /// In en, this message translates to:
  /// **'Default (Internal)'**
  String get setDefaultBackupFolder;

  /// No description provided for @setDataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get setDataManagement;

  /// No description provided for @setExportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export backup (JSON)'**
  String get setExportBackup;

  /// No description provided for @setExportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local backup file'**
  String get setExportBackupSubtitle;

  /// No description provided for @setImportBackup.
  ///
  /// In en, this message translates to:
  /// **'Import backup (JSON)'**
  String get setImportBackup;

  /// No description provided for @setImportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from local file'**
  String get setImportBackupSubtitle;

  /// No description provided for @setImportBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Backup'**
  String get setImportBackupTitle;

  /// No description provided for @setImportBackupBody.
  ///
  /// In en, this message translates to:
  /// **'This will REPLACE all your current data. This action cannot be undone.'**
  String get setImportBackupBody;

  /// No description provided for @setImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get setImport;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get statsTitle;

  /// No description provided for @statsError.
  ///
  /// In en, this message translates to:
  /// **'Error: {err}'**
  String statsError(String err);

  /// No description provided for @statsDistribution.
  ///
  /// In en, this message translates to:
  /// **'Distribution'**
  String get statsDistribution;

  /// No description provided for @statsTrends.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get statsTrends;

  /// No description provided for @statsBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get statsBreakdown;

  /// No description provided for @statsLedgerMonthly.
  ///
  /// In en, this message translates to:
  /// **'Ledger · Monthly'**
  String get statsLedgerMonthly;

  /// No description provided for @statsCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get statsCategories;

  /// No description provided for @statsNoTagsHint.
  ///
  /// In en, this message translates to:
  /// **'No tagged expenses in this period.'**
  String get statsNoTagsHint;

  /// No description provided for @statsNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity'**
  String get statsNoActivity;

  /// No description provided for @statsNothingRecorded.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded for {label}.'**
  String statsNothingRecorded(String label);

  /// No description provided for @statsTryAnotherPeriod.
  ///
  /// In en, this message translates to:
  /// **'Try another period from the filters above.'**
  String get statsTryAnotherPeriod;

  /// No description provided for @statsTrend12Months.
  ///
  /// In en, this message translates to:
  /// **'12-month trend'**
  String get statsTrend12Months;

  /// No description provided for @statsTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get statsTransactions;

  /// No description provided for @statsNoTransactionsIn.
  ///
  /// In en, this message translates to:
  /// **'No transactions in {label}.'**
  String statsNoTransactionsIn(String label);

  /// No description provided for @statsNothingRecordedCategory.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded for this category in {label}.'**
  String statsNothingRecordedCategory(String label);

  /// No description provided for @statsScopeExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get statsScopeExpenses;

  /// No description provided for @statsScopeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get statsScopeIncome;

  /// No description provided for @statsMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get statsMonth;

  /// No description provided for @statsYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get statsYear;

  /// No description provided for @statsTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get statsTotalSpent;

  /// No description provided for @statsTotalEarned.
  ///
  /// In en, this message translates to:
  /// **'Total earned'**
  String get statsTotalEarned;

  /// No description provided for @statsNetActivity.
  ///
  /// In en, this message translates to:
  /// **'Net activity'**
  String get statsNetActivity;

  /// No description provided for @statsDailyAvg.
  ///
  /// In en, this message translates to:
  /// **'Daily avg'**
  String get statsDailyAvg;

  /// No description provided for @statsNetFlow.
  ///
  /// In en, this message translates to:
  /// **'Net flow'**
  String get statsNetFlow;

  /// No description provided for @statsPredicted.
  ///
  /// In en, this message translates to:
  /// **'Predicted'**
  String get statsPredicted;

  /// No description provided for @statsSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get statsSavings;

  /// No description provided for @statsMonthlyBudget.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget'**
  String get statsMonthlyBudget;

  /// No description provided for @statsOver.
  ///
  /// In en, this message translates to:
  /// **'+{amount} over'**
  String statsOver(String amount);

  /// No description provided for @statsLeft.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String statsLeft(String amount);

  /// No description provided for @statsMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String statsMore(int count);

  /// No description provided for @statsMonthlyAvg.
  ///
  /// In en, this message translates to:
  /// **'Monthly avg'**
  String get statsMonthlyAvg;

  /// No description provided for @statsLargest.
  ///
  /// In en, this message translates to:
  /// **'Largest'**
  String get statsLargest;

  /// No description provided for @statsNoTrendData.
  ///
  /// In en, this message translates to:
  /// **'No trend data'**
  String get statsNoTrendData;

  /// No description provided for @statsEarned.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get statsEarned;

  /// No description provided for @statsSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get statsSpent;

  /// No description provided for @statsPctOf.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of total'**
  String statsPctOf(String pct);

  /// No description provided for @txActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get txActivity;

  /// No description provided for @txAllTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get txAllTime;

  /// No description provided for @txAllWallets.
  ///
  /// In en, this message translates to:
  /// **'All Wallets'**
  String get txAllWallets;

  /// No description provided for @txAlreadyInAccount.
  ///
  /// In en, this message translates to:
  /// **'Already in the account'**
  String get txAlreadyInAccount;

  /// No description provided for @txApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get txApplyFilters;

  /// No description provided for @txApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get txApprove;

  /// No description provided for @txBetweenYourWallets.
  ///
  /// In en, this message translates to:
  /// **'Between your wallets'**
  String get txBetweenYourWallets;

  /// No description provided for @txCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get txCategories;

  /// No description provided for @txCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get txCredit;

  /// No description provided for @txCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get txCustom;

  /// No description provided for @txDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get txDateRange;

  /// No description provided for @txDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {Are you sure you want to delete 1 item?} other {Are you sure you want to delete {count} items?}}'**
  String txDeleteConfirm(int count);

  /// No description provided for @txDeleteTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Transactions?'**
  String get txDeleteTransactionsTitle;

  /// No description provided for @txDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get txDetails;

  /// No description provided for @txDestinationWallet.
  ///
  /// In en, this message translates to:
  /// **'Destination wallet'**
  String get txDestinationWallet;

  /// No description provided for @txEditExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get txEditExpense;

  /// No description provided for @txEditIncome.
  ///
  /// In en, this message translates to:
  /// **'Edit income'**
  String get txEditIncome;

  /// No description provided for @txEditTransfer.
  ///
  /// In en, this message translates to:
  /// **'Edit transfer'**
  String get txEditTransfer;

  /// No description provided for @txEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get txEmail;

  /// No description provided for @txEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get txEnterAmount;

  /// No description provided for @txEnterDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter description'**
  String get txEnterDescription;

  /// No description provided for @txError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String txError(String error);

  /// No description provided for @txErrorLoadingAccounts.
  ///
  /// In en, this message translates to:
  /// **'Error loading accounts: {error}'**
  String txErrorLoadingAccounts(String error);

  /// No description provided for @txErrorLoadingCategories.
  ///
  /// In en, this message translates to:
  /// **'Error loading categories: {error}'**
  String txErrorLoadingCategories(String error);

  /// No description provided for @txErrorLoadingTags.
  ///
  /// In en, this message translates to:
  /// **'Error loading tags: {error}'**
  String txErrorLoadingTags(String error);

  /// No description provided for @txExternalOutflow.
  ///
  /// In en, this message translates to:
  /// **'Money going out'**
  String get txExternalOutflow;

  /// No description provided for @txFastCategorization.
  ///
  /// In en, this message translates to:
  /// **'Fast Categorization'**
  String get txFastCategorization;

  /// No description provided for @txFilterByWallet.
  ///
  /// In en, this message translates to:
  /// **'Filter by Wallet'**
  String get txFilterByWallet;

  /// No description provided for @txFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get txFilters;

  /// No description provided for @txFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get txFrom;

  /// No description provided for @txFromEmail.
  ///
  /// In en, this message translates to:
  /// **'From email'**
  String get txFromEmail;

  /// No description provided for @txIgnore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get txIgnore;

  /// No description provided for @txInstallment.
  ///
  /// In en, this message translates to:
  /// **'Installment'**
  String get txInstallment;

  /// No description provided for @txInstallmentOption.
  ///
  /// In en, this message translates to:
  /// **'{amount} × {count} · {paid} due so far'**
  String txInstallmentOption(String amount, int count, int paid);

  /// No description provided for @txInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get txInvalidAmount;

  /// No description provided for @txIsSameExpense.
  ///
  /// In en, this message translates to:
  /// **'Is this the same expense?'**
  String get txIsSameExpense;

  /// No description provided for @txLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 Days'**
  String get txLast30Days;

  /// No description provided for @txLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get txLast7Days;

  /// No description provided for @txLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get txLedger;

  /// No description provided for @txMovements.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get txMovements;

  /// No description provided for @txMovementUndecided.
  ///
  /// In en, this message translates to:
  /// **'Movement — to decide'**
  String get txMovementUndecided;

  /// No description provided for @txNewExpense.
  ///
  /// In en, this message translates to:
  /// **'New expense'**
  String get txNewExpense;

  /// No description provided for @txNewIncome.
  ///
  /// In en, this message translates to:
  /// **'New income'**
  String get txNewIncome;

  /// No description provided for @txNewTransfer.
  ///
  /// In en, this message translates to:
  /// **'New transfer'**
  String get txNewTransfer;

  /// No description provided for @txNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity'**
  String get txNoActivity;

  /// No description provided for @txNoContent.
  ///
  /// In en, this message translates to:
  /// **'(no content)'**
  String get txNoContent;

  /// No description provided for @txNoDifferent.
  ///
  /// In en, this message translates to:
  /// **'No, it\'s different'**
  String get txNoDifferent;

  /// No description provided for @txNoTransactionsPeriod.
  ///
  /// In en, this message translates to:
  /// **'No transactions in this period'**
  String get txNoTransactionsPeriod;

  /// No description provided for @txNoTransactionsToReview.
  ///
  /// In en, this message translates to:
  /// **'No transactions to review'**
  String get txNoTransactionsToReview;

  /// No description provided for @txNoWalletSelected.
  ///
  /// In en, this message translates to:
  /// **'No wallet selected'**
  String get txNoWalletSelected;

  /// No description provided for @txNotARate.
  ///
  /// In en, this message translates to:
  /// **'Not a rate'**
  String get txNotARate;

  /// No description provided for @txNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get txNote;

  /// No description provided for @txNoteHint.
  ///
  /// In en, this message translates to:
  /// **'What was this for?'**
  String get txNoteHint;

  /// No description provided for @txNotification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get txNotification;

  /// No description provided for @txOcrError.
  ///
  /// In en, this message translates to:
  /// **'OCR Error: {error}'**
  String txOcrError(String error);

  /// No description provided for @txPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get txPayment;

  /// No description provided for @txPossiblyAlreadyRecorded.
  ///
  /// In en, this message translates to:
  /// **'Possibly already recorded'**
  String get txPossiblyAlreadyRecorded;

  /// No description provided for @txPleaseSelectOtherWallet.
  ///
  /// In en, this message translates to:
  /// **'Please select a different destination wallet'**
  String get txPleaseSelectOtherWallet;

  /// No description provided for @txPleaseSelectWallet.
  ///
  /// In en, this message translates to:
  /// **'Please select a wallet'**
  String get txPleaseSelectWallet;

  /// No description provided for @txReceiptScanned.
  ///
  /// In en, this message translates to:
  /// **'Receipt scanned'**
  String get txReceiptScanned;

  /// No description provided for @txResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get txResetAll;

  /// No description provided for @txReviewBannerCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 transaction to review} other {{count} transactions to review}}'**
  String txReviewBannerCount(int count);

  /// No description provided for @txReviewInbox.
  ///
  /// In en, this message translates to:
  /// **'To review'**
  String get txReviewInbox;

  /// No description provided for @txScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get txScan;

  /// No description provided for @txSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get txSelect;

  /// No description provided for @txSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get txSelectCategory;

  /// No description provided for @txSelectDestination.
  ///
  /// In en, this message translates to:
  /// **'Select destination'**
  String get txSelectDestination;

  /// No description provided for @txSelectFromAccount.
  ///
  /// In en, this message translates to:
  /// **'Select From Account'**
  String get txSelectFromAccount;

  /// No description provided for @txSelectFromWallet.
  ///
  /// In en, this message translates to:
  /// **'Select From Wallet'**
  String get txSelectFromWallet;

  /// No description provided for @txSelectSource.
  ///
  /// In en, this message translates to:
  /// **'Select source'**
  String get txSelectSource;

  /// No description provided for @txSelectToAccount.
  ///
  /// In en, this message translates to:
  /// **'Select To Account'**
  String get txSelectToAccount;

  /// No description provided for @txSelectToWallet.
  ///
  /// In en, this message translates to:
  /// **'Select To Wallet'**
  String get txSelectToWallet;

  /// No description provided for @txSelectWallet.
  ///
  /// In en, this message translates to:
  /// **'Select wallet'**
  String get txSelectWallet;

  /// No description provided for @txSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 selected} other {{count} selected}}'**
  String txSelected(int count);

  /// No description provided for @txSepaUndecided.
  ///
  /// In en, this message translates to:
  /// **'SEPA transfer — to decide'**
  String get txSepaUndecided;

  /// No description provided for @txSourceWallet.
  ///
  /// In en, this message translates to:
  /// **'Source wallet'**
  String get txSourceWallet;

  /// No description provided for @txSwipeNext.
  ///
  /// In en, this message translates to:
  /// **'Swipe for next transaction'**
  String get txSwipeNext;

  /// No description provided for @txTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get txTo;

  /// No description provided for @txTransferDetails.
  ///
  /// In en, this message translates to:
  /// **'Transfer Details'**
  String get txTransferDetails;

  /// No description provided for @txTransactionAdded.
  ///
  /// In en, this message translates to:
  /// **'Transaction added'**
  String get txTransactionAdded;

  /// No description provided for @txTransactionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Transaction updated'**
  String get txTransactionUpdated;

  /// No description provided for @txUnrecognizedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 unrecognized message} other {{count} unrecognized messages}}'**
  String txUnrecognizedCount(int count);

  /// No description provided for @txUnrecognizedMessages.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized messages'**
  String get txUnrecognizedMessages;

  /// No description provided for @txUnreadableMessage.
  ///
  /// In en, this message translates to:
  /// **'{kind} from {source} on {date} — couldn\'t read it'**
  String txUnreadableMessage(String kind, String source, String date);

  /// No description provided for @txUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get txUpdate;

  /// No description provided for @txWhatKindOfTransfer.
  ///
  /// In en, this message translates to:
  /// **'What kind of transfer is this?'**
  String get txWhatKindOfTransfer;

  /// No description provided for @txYesSame.
  ///
  /// In en, this message translates to:
  /// **'Yes, it\'s the same'**
  String get txYesSame;

  /// No description provided for @txYouReceived.
  ///
  /// In en, this message translates to:
  /// **'You received'**
  String get txYouReceived;

  /// No description provided for @txYouSpent.
  ///
  /// In en, this message translates to:
  /// **'You spent'**
  String get txYouSpent;

  /// No description provided for @txYouTransferred.
  ///
  /// In en, this message translates to:
  /// **'You transferred'**
  String get txYouTransferred;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Check the connection and try again.'**
  String get errNetwork;

  /// No description provided for @errServer.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the request (code {code}).'**
  String errServer(int code);

  /// No description provided for @errUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errUnexpected;

  /// No description provided for @commonDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get commonDiscardTitle;

  /// No description provided for @commonDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'What you typed here has not been saved.'**
  String get commonDiscardBody;

  /// No description provided for @commonDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get commonDiscard;

  /// No description provided for @commonKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get commonKeepEditing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
