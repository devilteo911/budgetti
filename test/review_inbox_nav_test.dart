import 'package:budgetti/core/router/app_router.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Every bank-draft notification tap opens the review inbox; a Partita IVA
/// reminder's opens the deadlines instead. A second tap while the screen is
/// already the one on top must not stack another copy.
void main() {
  const reminderPayload = 'piva:2027-06-30T09:00:00.000Z';

  Future<GoRouter> pump(WidgetTester tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('home')),
      GoRoute(path: reviewInboxPath, builder: (_, __) => const Text('inbox')),
      // Shows the query it was opened with: that is what the real screen reads.
      GoRoute(
        path: '/piva',
        builder: (_, state) => Text('piva ${state.uri.queryParameters['section']}'),
      ),
      GoRoute(path: '/other', builder: (_, __) => const Text('other')),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a tap from elsewhere opens the inbox', (tester) async {
    final router = await pump(tester);

    openReviewInbox(router);
    await tester.pumpAndSettle();

    expect(find.text('inbox'), findsOneWidget);
  });

  testWidgets('a second tap while on the inbox does not stack another',
      (tester) async {
    final router = await pump(tester);

    openReviewInbox(router);
    await tester.pumpAndSettle();
    openReviewInbox(router);
    await tester.pumpAndSettle();
    openReviewInbox(router);
    await tester.pumpAndSettle();

    // One back press reaches home: there was only one inbox on the stack.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('from another pushed screen it opens the inbox on top',
      (tester) async {
    final router = await pump(tester);
    router.push('/other');
    await tester.pumpAndSettle();

    openReviewInbox(router);
    await tester.pumpAndSettle();

    expect(find.text('inbox'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('other'), findsOneWidget); // the screen it came from
  });

  testWidgets('a reminder payload opens /piva on its deadlines', (tester) async {
    final router = await pump(tester);

    openFromNotification(router, reminderPayload);
    await tester.pumpAndSettle();

    expect(find.text('piva deadlines'), findsOneWidget);
    expect(find.text('inbox'), findsNothing);
  });

  for (final payload in ['a-draft-id', bankDraftsSummaryPayload]) {
    testWidgets('the payload "$payload" still opens the inbox', (tester) async {
      final router = await pump(tester);

      openFromNotification(router, payload);
      await tester.pumpAndSettle();

      expect(find.text('inbox'), findsOneWidget);
      expect(find.textContaining('piva'), findsNothing);
    });
  }

  testWidgets('a second reminder tap while on /piva does not stack another',
      (tester) async {
    final router = await pump(tester);

    openFromNotification(router, reminderPayload);
    await tester.pumpAndSettle();
    openFromNotification(router, reminderPayload);
    await tester.pumpAndSettle();
    openFromNotification(router, reminderPayload);
    await tester.pumpAndSettle();

    expect(find.text('piva deadlines'), findsOneWidget);
    // One back press reaches home: there was only one /piva on the stack.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('a reminder tap from another pushed screen opens /piva on top',
      (tester) async {
    final router = await pump(tester);
    router.push('/other');
    await tester.pumpAndSettle();

    openFromNotification(router, reminderPayload);
    await tester.pumpAndSettle();

    expect(find.text('piva deadlines'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('other'), findsOneWidget); // the screen it came from
  });
}
