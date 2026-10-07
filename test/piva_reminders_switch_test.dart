import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart' show FinanceService;
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:budgetti/core/services/piva_reminders.dart' show PivaReminder;
import 'package:budgetti/features/settings/preferences_screen.dart';
import 'package:budgetti/features/settings/widgets/settings_tile.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:budgetti/l10n/app_localizations_it.dart';
import 'package:budgetti/models/piva.dart' show PivaPaymentData, PivaProfileData, deadlines;
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The reminders reach the ledger only through the providers below; nothing of the
/// service is read.
class _Finance extends Fake implements FinanceService {}

/// The system as the screen sees it: what the permission check says
/// ([granted]), what the permission prompt answers ([grants]), and the plans
/// handed to the device. Nothing reaches the plugin.
class _Service extends NotificationService {
  _Service({this.granted = true, this.grants = true});

  bool granted;
  bool grants;
  var requests = 0;
  final plans = <List<PivaReminder>>[];

  @override
  Future<bool> isPermissionGranted() async => granted;

  @override
  Future<bool> requestPermissions() async {
    requests++;
    return grants;
  }

  @override
  Future<void> syncPivaReminders(List<PivaReminder> plan) async => plans.add(plan);

  // The general switch reschedules the daily reminder: no plugin in a test.
  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<void> scheduleDailyReminder({required int id, required int hour, required int minute}) async {}
}

// A made-up Gestione Separata profile with no income in the ledger: its calendar
// is empty, so the plan holds only the deadline a test adds.
const _profile = PivaProfileData(
  atecoCode: '62.01',
  coefficient: 67,
  startYear: 2020,
  startupRate: false,
  fundType: 'gestione_separata',
  fundName: '',
  subjectiveRate: 0,
  integrativeRate: 0,
  minSubjective: 0,
  minIntegrative: 0,
  inpsReduction: false,
  incomeCategories: ['Freelance'],
);

/// A deadline added by hand, 40 days from today: the plan has its reminders (the
/// provider reads the real clock, so a fixed date would one day be past).
PivaPaymentData _bollo() {
  final soon = DateTime.now().add(const Duration(days: 40));
  return PivaPaymentData(
    id: 'p-bollo',
    key: '',
    kind: 'imposta',
    label: 'Bollo',
    dueDate: DateTime(soon.year, soon.month, soon.day),
    amount: 120,
    paidDate: null,
    note: '',
  );
}

/// One state of the row: what the screen is given and what the row must show.
class _Case {
  _Case(
    this.name, {
    this.profile = _profile,
    this.prefs = const {},
    this.granted = true,
    required this.subtitle,
    required this.on,
    required this.enabled,
  });

  final String name;
  final PivaProfileData? profile;
  final Map<String, Object> prefs;
  final bool granted;
  final String subtitle;
  final bool on;
  final bool enabled;
}

/// The Settings → Preferences row of the Partita IVA reminders, in its four states,
/// what a tap does in each, and the narrow phone with a large font. The screen is
/// given made-up Partita IVA data through the providers, with the reminders
/// provider kept alive (as `main()` does) so what the row writes shows up as the plan
/// handed to the device.
void main() {
  setUpAll(() {
    // The plan reads Italy's clock from tz.local, which NotificationService.init()
    // sets in the app.
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));
  });

  final en = AppLocalizationsEn();

  /// Waits out the 50 ms debounce of the reminders provider (the fake clock runs
  /// 100 ms, so its timer fires and the plan it hands over is recorded), then the
  /// frames that follow. A test ends with this, so no timer is left pending.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  /// The screen over [prefs], with [profile] and [payments] as the Partita IVA
  /// sources. The reminders provider is kept alive by a listener on the container
  /// (as `main()` does), with a 50 ms debounce; [settle] waits it out.
  Future<({_Service service, SharedPreferences prefs})> pump(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    PivaProfileData? profile = _profile,
    List<PivaPaymentData> payments = const [],
    bool granted = true,
    bool grants = true,
    Locale locale = const Locale('en'),
    Size size = const Size(360, 3000),
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final service = _Service(granted: granted, grants: grants);

    final debounce = pivaRemindersDebounce;
    pivaRemindersDebounce = const Duration(milliseconds: 50);
    addTearDown(() => pivaRemindersDebounce = debounce);
    final container = ProviderContainer(
      overrides: [
        persistenceServiceProvider.overrideWithValue(PersistenceService(sp)),
        notificationServiceProvider.overrideWithValue(service),
        financeServiceProvider.overrideWithValue(_Finance()),
        userProfileProvider.overrideWith((ref) async => <String, dynamic>{'currency': 'EUR'}),
        pivaProfileProvider.overrideWith((ref) => Stream.value(profile)),
        pivaPaymentsProvider.overrideWith((ref) => Stream.value(payments)),
        pivaTransactionsProvider.overrideWith((ref) => Stream.value(const <Transaction>[])),
      ],
    );
    addTearDown(container.dispose);
    container.listen(pivaRemindersSyncProvider, (_, __) {});

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const PreferencesScreen(),
        ),
      ),
    );
    await settle(tester);
    return (service: service, prefs: sp);
  }

  Finder tile(String title) => find.ancestor(of: find.text(title), matching: find.byType(SettingsTile));
  Finder switchOf(String title) => find.descendant(of: tile(title), matching: find.byType(Switch));
  Switch switchWidget(WidgetTester tester, String title) => tester.widget<Switch>(switchOf(title));

  testWidgets('no profile: off, disabled, and says so; a tap does nothing', (tester) async {
    final t = await pump(tester, profile: null);
    final plans = t.service.plans.length;

    expect(find.text(en.pivaRemNoProfile), findsOneWidget);
    expect(switchWidget(tester, en.pivaRemSwitch).value, isFalse);
    expect(switchWidget(tester, en.pivaRemSwitch).onChanged, isNull);

    await tester.tap(switchOf(en.pivaRemSwitch), warnIfMissed: false);
    await settle(tester);

    expect(t.prefs.containsKey('piva_reminders_enabled'), isFalse);
    expect(t.service.requests, 0);
    expect(switchWidget(tester, en.pivaRemSwitch).value, isFalse);
    expect(t.service.plans, hasLength(plans), reason: 'nothing to replan');
  });

  testWidgets('a profile: on; off writes the pref and, after the debounce, an empty plan; on writes true again',
      (tester) async {
    expect(deadlines(_profile, const [], const [], DateTime.now()), isEmpty, reason: 'the premise: no estimated row');
    final t = await pump(tester, payments: [_bollo()]);

    expect(find.text(en.pivaRemSwitchSubtitle), findsOneWidget);
    expect(switchWidget(tester, en.pivaRemSwitch).value, isTrue);
    expect(t.service.plans, isNotEmpty);
    expect(t.service.plans.last, isNotEmpty, reason: 'the premise: the deadline has reminders');

    await tester.tap(switchOf(en.pivaRemSwitch));
    await settle(tester);

    expect(t.prefs.getBool('piva_reminders_enabled'), isFalse);
    expect(switchWidget(tester, en.pivaRemSwitch).value, isFalse);
    expect(find.text(en.pivaRemSwitchSubtitle), findsOneWidget, reason: 'off by choice, not blocked');
    expect(t.service.plans.last, isEmpty);
    expect(t.service.requests, 0, reason: 'turning off asks for nothing');

    await tester.tap(switchOf(en.pivaRemSwitch));
    await settle(tester);

    expect(t.prefs.getBool('piva_reminders_enabled'), isTrue);
    expect(switchWidget(tester, en.pivaRemSwitch).value, isTrue);
    expect(t.service.plans.last, isNotEmpty);
  });

  testWidgets('the general switch off: disabled, says so, and a tap does nothing', (tester) async {
    final t = await pump(tester, prefs: {'notifications_enabled': false});

    expect(find.text(en.pivaRemMasterOff), findsOneWidget);
    expect(switchWidget(tester, en.pivaRemSwitch).value, isFalse);
    expect(switchWidget(tester, en.pivaRemSwitch).onChanged, isNull);

    await tester.tap(switchOf(en.pivaRemSwitch), warnIfMissed: false);
    await settle(tester);

    expect(t.prefs.containsKey('piva_reminders_enabled'), isFalse);
    expect(t.service.requests, 0);
  });

  testWidgets('the general switch turned on again replans, and the row is live again', (tester) async {
    final t = await pump(tester, prefs: {'notifications_enabled': false}, payments: [_bollo()]);
    expect(t.service.plans.last, isEmpty, reason: 'nothing is planned under a switch that is off');

    await tester.tap(switchOf(en.setPushNotifications));
    await settle(tester);

    expect(t.prefs.getBool('notifications_enabled'), isTrue);
    expect(t.service.plans.last, isNotEmpty);
    expect(find.text(en.pivaRemSwitchSubtitle), findsOneWidget);
    expect(switchWidget(tester, en.pivaRemSwitch).onChanged, isNotNull);
  });

  testWidgets('notifications blocked by the system: off but tappable; denied changes nothing, granted turns it on',
      (tester) async {
    final t = await pump(tester, payments: [_bollo()], granted: false, grants: false);

    expect(find.text(en.pivaRemBlocked), findsOneWidget);
    expect(find.text(en.setFixPermissions), findsOneWidget, reason: 'the existing row stays');
    expect(switchWidget(tester, en.pivaRemSwitch).value, isFalse);
    expect(switchWidget(tester, en.pivaRemSwitch).onChanged, isNotNull);

    // The prompt is refused: nothing written, still blocked.
    await tester.tap(switchOf(en.pivaRemSwitch));
    await settle(tester);

    expect(t.service.requests, 1);
    expect(t.prefs.containsKey('piva_reminders_enabled'), isFalse);
    expect(find.text(en.pivaRemBlocked), findsOneWidget);
    expect(switchWidget(tester, en.pivaRemSwitch).value, isFalse);

    // The prompt is accepted: the pref is written and the row is normal again.
    t.service.grants = true;
    await tester.tap(switchOf(en.pivaRemSwitch));
    await settle(tester);

    expect(t.service.requests, 2);
    expect(t.prefs.getBool('piva_reminders_enabled'), isTrue);
    expect(find.text(en.pivaRemBlocked), findsNothing);
    expect(find.text(en.pivaRemSwitchSubtitle), findsOneWidget);
    expect(switchWidget(tester, en.pivaRemSwitch).value, isTrue);
    expect(find.text(en.setFixPermissions), findsNothing);
    expect(t.service.plans.last, isNotEmpty);
  });

  // The first state that holds decides the row, in this order; nothing in it is
  // red (a switch that cannot be turned on is not an error).
  final cases = [
    _Case('no profile', profile: null, subtitle: en.pivaRemNoProfile, on: false, enabled: false),
    _Case(
      'no profile beats the general switch being off',
      profile: null,
      prefs: {'notifications_enabled': false},
      subtitle: en.pivaRemNoProfile,
      on: false,
      enabled: false,
    ),
    _Case(
      'the general switch off',
      prefs: {'notifications_enabled': false},
      subtitle: en.pivaRemMasterOff,
      on: false,
      enabled: false,
    ),
    _Case('blocked by the system', granted: false, subtitle: en.pivaRemBlocked, on: false, enabled: true),
    _Case(
      'blocked by the system beats the pref being on',
      prefs: {'piva_reminders_enabled': true},
      granted: false,
      subtitle: en.pivaRemBlocked,
      on: false,
      enabled: true,
    ),
    _Case('normal, on by default', subtitle: en.pivaRemSwitchSubtitle, on: true, enabled: true),
    _Case(
      'normal, switched off',
      prefs: {'piva_reminders_enabled': false},
      subtitle: en.pivaRemSwitchSubtitle,
      on: false,
      enabled: true,
    ),
  ];
  for (final c in cases) {
    testWidgets('state: ${c.name}', (tester) async {
      await pump(tester, profile: c.profile, prefs: c.prefs, granted: c.granted);

      expect(find.text(c.subtitle), findsOneWidget);
      final s = switchWidget(tester, en.pivaRemSwitch);
      expect(s.value, c.on);
      expect(s.onChanged != null, c.enabled);

      final error = Theme.of(tester.element(find.byType(PreferencesScreen))).colorScheme.error;
      for (final t in tester.widgetList<Text>(find.descendant(of: tile(en.pivaRemSwitch), matching: find.byType(Text)))) {
        expect(t.style?.color, isNot(error), reason: t.data);
      }
      final icon = find.descendant(of: tile(en.pivaRemSwitch), matching: find.byIcon(Icons.account_balance_outlined));
      expect(tester.widget<Icon>(icon).color, isNot(error));
    });
  }

  // The Italian subtitle is the long one: 360 dp, a large font, both languages.
  for (final (locale, l10n) in [
    (const Locale('it'), AppLocalizationsIt()),
    (const Locale('en'), AppLocalizationsEn()),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('360 wide, $locale at text scale $scale: the subtitle wraps whole, targets of 48', (tester) async {
        await pump(tester, locale: locale, textScale: scale);

        expect(tester.takeException(), isNull);
        final subtitle = find.text(l10n.pivaRemSwitchSubtitle);
        expect(subtitle, findsOneWidget);
        expect(tester.renderObject<RenderParagraph>(subtitle).didExceedMaxLines, isFalse);
        final row = tester.getRect(tile(l10n.pivaRemSwitch));
        expect(tester.getRect(subtitle).right, lessThanOrEqualTo(row.right));
        expect(row.height, greaterThanOrEqualTo(48));
        final size = tester.getSize(switchOf(l10n.pivaRemSwitch));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      });
    }
  }

  for (final (name, profile, label, enabled, toggled) in <(String, PivaProfileData?, String, bool, bool)>[
    ('a screen reader hears title, subtitle and "on" as one thing', _profile, en.pivaRemSwitchSubtitle, true, true),
    ('a screen reader hears the reason and "disabled"', null, en.pivaRemNoProfile, false, false),
  ]) {
    testWidgets(name, (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, profile: profile);

      final node = tester.getSemantics(find.text(en.pivaRemSwitch));
      expect(node.label, contains(en.pivaRemSwitch));
      expect(node.label, contains(label));
      final flags = node.getSemanticsData().flagsCollection;
      expect(flags.hasToggledState, isTrue);
      expect(flags.isToggled, toggled);
      expect(flags.hasEnabledState, isTrue);
      expect(flags.isEnabled, enabled);
      handle.dispose();
    });
  }
}
