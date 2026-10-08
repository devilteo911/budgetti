import 'dart:async';

import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/auth_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The session as the providers see it: an id and a `changes` stream. The real
// AuthService adds a PocketBase client and a database that nothing here needs.
class _FakeAuth extends Fake implements AuthService {
  final _changes = StreamController<void>.broadcast();

  @override
  String? pbUserId;

  @override
  Stream<void> get changes => _changes.stream;

  /// Sets the id, then fires the event login() and logout() fire — always null.
  void emit(String? id) {
    pbUserId = id;
    _changes.add(null);
  }
}

void main() {
  // On a fresh install a pre-login 401 runs logout() and the real login()
  // follows. Both emit `null`, and Riverpod drops an AsyncData equal to the
  // previous one, so the login never reached currentUserIdProvider: it kept the
  // local id, and the services below it stamped every pulled row with it.
  test('a login after a pre-login logout reaches currentUserIdProvider',
      () async {
    SharedPreferences.setMockInitialValues({});
    final persistence =
        PersistenceService(await SharedPreferences.getInstance());
    await persistence.setLocalUserId('local');
    final auth = _FakeAuth();
    final container = ProviderContainer.test(overrides: [
      authServiceProvider.overrideWithValue(auth),
      persistenceServiceProvider.overrideWithValue(persistence),
    ]);
    // The app keeps these alive (router, services); an unlistened chain would
    // not be subscribed to the auth stream.
    container.listen(currentUserIdProvider, (_, _) {});
    expect(container.read(currentUserIdProvider), 'local');

    Future<void> settle() async {
      await Future<void>.delayed(Duration.zero);
      await container.pump();
    }

    auth.emit(null); // the 401 before login
    await settle();
    auth.emit('u1'); // the login itself
    await settle();

    expect(container.read(currentUserIdProvider), 'u1');
  });
}
