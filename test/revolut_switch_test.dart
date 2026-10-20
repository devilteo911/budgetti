import 'package:budgetti/core/database/database.dart' show PendingTransaction;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/bank_sync_service.dart';
import 'package:budgetti/core/services/google_auth_service.dart';
import 'package:budgetti/core/services/notification_listener_service.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/features/settings/integrations_screen.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Listener implements NotificationListenerService {
  bool access = false;
  int opened = 0;
  @override
  Future<bool> isAccessEnabled() async => access;
  @override
  Future<void> openSettings() async => opened++;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Counts the "read now" drains; nothing new in either buffer.
class _Bank implements BankSyncService {
  int drains = 0;
  @override
  Future<List<PendingTransaction>> syncNotifications() async {
    drains++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Logic implements NotificationLogic {
  @override
  Future<void> updateBankSyncSchedule() async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth implements GoogleAuthService {
  @override
  GoogleSignInAccount? get currentUser => null;
  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged => const Stream.empty();
  @override
  Future<GoogleSignInAccount?> signInSilently() async => null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// The Revolut switch flipped ON the moment it was tapped and stayed ON after
/// "Later" while the row below said "Not granted". It now shows whether capture
/// is actually working — switched on AND allowed.
void main() {
  final l10n = AppLocalizationsEn();
  late _Listener listener;
  late _Bank bank;
  late SharedPreferences prefs;

  Future<void> pumpScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationListenerProvider.overrideWithValue(listener),
      bankSyncServiceProvider.overrideWithValue(bank),
      notificationLogicProvider.overrideWithValue(_Logic()),
      googleAuthServiceProvider.overrideWithValue(_Auth()),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const IntegrationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The Revolut tile is the first switch on the screen (the email-sync one only
  // shows with a Google account, and auto-backup comes after).
  Finder revolutSwitch() => find.byType(Switch).first;

  bool switchOn(WidgetTester tester) =>
      tester.widget<Switch>(revolutSwitch()).value;

  setUp(() {
    listener = _Listener();
    bank = _Bank();
  });

  testWidgets('without access the switch stays off and the row says so', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(revolutSwitch());
    await tester.pumpAndSettle();
    expect(find.text(l10n.setNotificationAccess), findsWidgets); // the dialog
    await tester.tap(find.text(l10n.setLater));
    await tester.pumpAndSettle();

    expect(switchOn(tester), isFalse, reason: 'capture is not working');
    expect(find.text(l10n.setNotGranted), findsOneWidget);
  });

  testWidgets('it turns on by itself once access is granted', (tester) async {
    await pumpScreen(tester);
    await tester.tap(revolutSwitch());
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.setOpenSettings));
    await tester.pumpAndSettle();
    expect(listener.opened, 1);
    expect(switchOn(tester), isFalse);

    // The owner grants access on the system screen and comes back.
    listener.access = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(switchOn(tester), isTrue);
    expect(find.text(l10n.setGranted), findsOneWidget);
  });

  testWidgets('with access already granted it turns on at once, no dialog', (
    tester,
  ) async {
    listener.access = true;
    await pumpScreen(tester);

    await tester.tap(revolutSwitch());
    await tester.pumpAndSettle();

    expect(switchOn(tester), isTrue);
    expect(find.text(l10n.setOpenSettings), findsNothing);
  });

  testWidgets(
    'tapping a switch that shows off but is waiting cancels the wait',
    (tester) async {
      await pumpScreen(tester);
      await tester.tap(revolutSwitch());
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.setLater));
      await tester.pumpAndSettle();
      expect(find.text(l10n.setNotGranted), findsOneWidget);

      await tester.tap(revolutSwitch());
      await tester.pumpAndSettle();

      expect(switchOn(tester), isFalse);
      expect(find.text(l10n.setNotGranted), findsNothing);
      expect(find.text(l10n.setOpenSettings), findsNothing);
    },
  );

  testWidgets('switching a working capture off turns it off', (tester) async {
    listener.access = true;
    await pumpScreen(tester);
    await tester.tap(revolutSwitch());
    await tester.pumpAndSettle();

    await tester.tap(revolutSwitch());
    await tester.pumpAndSettle();

    expect(switchOn(tester), isFalse);
  });

  // PayPal is the second switch of the same section: same listener, same access
  // grant, same logic, its own pref.
  group('the PayPal switch', () {
    Finder paypalSwitch() => find.byType(Switch).at(1);
    bool paypalOn(WidgetTester tester) =>
        tester.widget<Switch>(paypalSwitch()).value;

    testWidgets('sits below the Revolut one, with its own labels', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text(l10n.setSyncPayPalNotifications), findsOneWidget);
      expect(find.text(l10n.setSyncPayPalNotificationsSubtitle), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(l10n.setSyncPayPalNotifications)).dy,
        greaterThan(
          tester.getTopLeft(find.text(l10n.setSyncRevolutNotifications)).dy,
        ),
      );
      expect(paypalOn(tester), isFalse);
    });

    testWidgets('with access granted it turns on alone, Revolut stays off', (
      tester,
    ) async {
      listener.access = true;
      await pumpScreen(tester);

      await tester.tap(paypalSwitch());
      await tester.pumpAndSettle();

      expect(paypalOn(tester), isTrue);
      expect(switchOn(tester), isFalse);
      expect(find.text(l10n.setOpenSettings), findsNothing);
      expect(prefs.getBool('paypal_sync_enabled'), isTrue);
      expect(prefs.getBool('revolut_sync_enabled'), isNot(isTrue));
    });

    testWidgets('without access it stays off and the row says so', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(paypalSwitch());
      await tester.pumpAndSettle();
      expect(find.text(l10n.setNotificationAccess), findsWidgets); // the dialog
      await tester.tap(find.text(l10n.setLater));
      await tester.pumpAndSettle();

      expect(paypalOn(tester), isFalse, reason: 'capture is not working');
      expect(find.text(l10n.setNotGranted), findsOneWidget);
    });

    testWidgets('it turns on by itself once access is granted', (tester) async {
      await pumpScreen(tester);
      await tester.tap(paypalSwitch());
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.setOpenSettings));
      await tester.pumpAndSettle();
      expect(listener.opened, 1);
      expect(paypalOn(tester), isFalse);

      listener.access = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(paypalOn(tester), isTrue);
      expect(switchOn(tester), isFalse);
    });

    testWidgets('tapping it while it waits for access cancels the wait', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(paypalSwitch());
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.setLater));
      await tester.pumpAndSettle();

      await tester.tap(paypalSwitch());
      await tester.pumpAndSettle();

      expect(paypalOn(tester), isFalse);
      expect(find.text(l10n.setNotGranted), findsNothing);
      expect(find.text(l10n.setOpenSettings), findsNothing);
      expect(prefs.getBool('paypal_sync_enabled'), isFalse);
    });

    testWidgets('the access and read-now rows show while either switch is on', (
      tester,
    ) async {
      listener.access = true;
      await pumpScreen(tester);
      Finder readNow() => find.text(l10n.setReadNotificationsNow);
      Finder accessRow() => find.text(l10n.setGranted);
      expect(readNow(), findsNothing);
      expect(accessRow(), findsNothing);

      await tester.tap(paypalSwitch()); // PayPal alone
      await tester.pumpAndSettle();
      expect(readNow(), findsOneWidget);
      expect(accessRow(), findsOneWidget);

      await tester.tap(revolutSwitch()); // both
      await tester.pumpAndSettle();
      await tester.tap(paypalSwitch()); // Revolut alone
      await tester.pumpAndSettle();
      expect(readNow(), findsOneWidget);
      expect(accessRow(), findsOneWidget);

      await tester.tap(revolutSwitch()); // none
      await tester.pumpAndSettle();
      expect(readNow(), findsNothing);
      expect(accessRow(), findsNothing);
    });

    // "Read now" drains whichever source is on and does not name Revolut when
    // the one that is on is PayPal.
    for (final (name, source) in [
      ('PayPal', () => find.byType(Switch).at(1)),
      ('Revolut', () => find.byType(Switch).first),
    ]) {
      testWidgets('reading $name alone with nothing new says so neutrally', (
        tester,
      ) async {
        listener.access = true;
        await pumpScreen(tester);
        await tester.tap(source());
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.setReadNotificationsNow));
        await tester.pumpAndSettle();

        expect(bank.drains, 1);
        expect(find.text(l10n.setNoNewNotifications), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining('Revolut'),
          ),
          findsNothing,
        );
      });
    }
  });
}
