import 'package:budgetti/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Every bank-draft notification tap opens the review inbox. A second tap while
/// it is already the screen on top must not stack another copy.
void main() {
  Future<GoRouter> pump(WidgetTester tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('home')),
      GoRoute(path: reviewInboxPath, builder: (_, __) => const Text('inbox')),
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
}
