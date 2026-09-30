import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:budgetti/core/services/notification_listener_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Revolut listener buffers pushes into a JSON file; [drain] is how the app
/// takes them out. Foreground launch, resume, pull-to-refresh and the
/// background task all drain it, so two drains can meet — and the buffer is the
/// only copy of a push, so a drain must neither lose one nor read one twice.
void main() {
  late Directory dir;
  late File buffer;
  late File claim;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('budgetti_drain_');
    buffer = File('${dir.path}/revolut_notifications.json');
    claim = File('${buffer.path}.draining');
  });

  tearDown(() => dir.delete(recursive: true));

  String push(String key) =>
      jsonEncode({'key': key, 'title': 'Revolut', 'text': 'Hai speso €1', 'when': 1});

  Future<void> write(File f, List<String> keys) =>
      f.writeAsString('[${keys.map(push).join(',')}]');

  test('returns what was buffered and leaves no file behind', () async {
    await write(buffer, ['a', 'b']);

    final got = await NotificationListenerService.drain(buffer);

    expect(got.map((n) => n.key), ['a', 'b']);
    expect(buffer.existsSync(), isFalse);
    expect(claim.existsSync(), isFalse);
  });

  test('a second drain right after finds nothing', () async {
    await write(buffer, ['a']);
    await NotificationListenerService.drain(buffer);

    expect(await NotificationListenerService.drain(buffer), isEmpty);
  });

  test('no buffer is an empty drain, not an error', () async {
    expect(await NotificationListenerService.drain(buffer), isEmpty);
  });

  test('two drains at once: exactly one gets the pushes', () async {
    await write(buffer, ['a', 'b', 'c']);

    final results = await Future.wait([
      NotificationListenerService.drain(buffer),
      NotificationListenerService.drain(buffer),
    ]);

    expect(results.map((r) => r.length).toList()..sort(), [0, 3]);
  });

  test('a claim left by a drain that died is finished first, nothing lost',
      () async {
    await write(claim, ['old1', 'old2']); // died between rename and delete
    await write(buffer, ['new']); // and the listener kept capturing

    final got = await NotificationListenerService.drain(buffer);

    expect(got.map((n) => n.key), ['old1', 'old2', 'new']);
    expect(claim.existsSync(), isFalse);
    expect(buffer.existsSync(), isFalse);
  });

  test('a corrupt claim is dropped and does not block the live buffer',
      () async {
    await claim.writeAsString('[{"key": "trunc');
    await write(buffer, ['new']);

    final got = await NotificationListenerService.drain(buffer);

    expect(got.map((n) => n.key), ['new']);
    expect(claim.existsSync(), isFalse);
  });

  test('a corrupt buffer is empty, and is not retried forever', () async {
    await buffer.writeAsString('not json');

    expect(await NotificationListenerService.drain(buffer), isEmpty);
    expect(buffer.existsSync(), isFalse);
    expect(claim.existsSync(), isFalse);
  });

  test('a push captured while a drain holds the claim goes to a fresh buffer',
      () async {
    await write(buffer, ['a']);
    final pending = NotificationListenerService.drain(buffer);
    // The listener appends while the drain is in flight (it reads the buffer,
    // adds the push and rewrites the file; a missing file starts a new one).
    final live = buffer.existsSync()
        ? (jsonDecode(buffer.readAsStringSync()) as List)
        : [];
    buffer.writeAsStringSync(jsonEncode([...live, jsonDecode(push('b'))]));

    final got = await pending;
    final rest = await NotificationListenerService.drain(buffer);

    // Whatever the interleaving, every push comes out exactly once.
    expect([...got, ...rest].map((n) => n.key).toSet(), {'a', 'b'});
    expect(got.length + rest.length, 2);
  });

  // The loss race: drain B (another isolate) finds no claim, drain A then claims
  // buffer 1 but has not read it yet, the listener writes buffer 2, and B claims
  // buffer 2. With one shared claim name, B's rename REPLACED A's claim and
  // buffer 1 was destroyed unread.
  test('a drain claiming while another holds an unread claim destroys nothing',
      () async {
    await write(buffer, ['one']);
    final bLooked = Completer<void>(), releaseB = Completer<void>();
    final aClaimed = Completer<void>(), releaseA = Completer<void>();

    // B has looked for leftover claims, found none, and stalls.
    final b = NotificationListenerService.drainInterleaved(buffer, (stage) async {
      if (stage == 'recovered') {
        bLooked.complete();
        await releaseB.future;
      }
    });
    await bLooked.future;
    // A claims buffer 1 and stalls before reading it.
    final a = NotificationListenerService.drainInterleaved(buffer, (stage) async {
      if (stage == 'claimed') {
        aClaimed.complete();
        await releaseA.future;
      }
    });
    await aClaimed.future;
    // The listener starts a fresh buffer while A still holds buffer 1.
    await write(buffer, ['two']);

    releaseB.complete();
    final gotB = await b;
    releaseA.complete();
    final gotA = await a;

    expect([...gotA, ...gotB].map((n) => n.key).toList()..sort(), ['one', 'two']);
  });

  test('claims left under any name are all recovered, oldest first', () async {
    await write(File('${buffer.path}.draining.2000-2'), ['second']);
    await write(File('${buffer.path}.draining.1000-1'), ['first']);
    await write(buffer, ['live']);

    final got = await NotificationListenerService.drain(buffer);

    expect(got.map((n) => n.key), ['first', 'second', 'live']);
    expect(dir.listSync().whereType<File>(), isEmpty);
  });

  test('other files in the directory are left alone', () async {
    final other = File('${dir.path}/something_else.draining');
    await write(other, ['x']);
    await write(buffer, ['a']);

    final got = await NotificationListenerService.drain(buffer);

    expect(got.map((n) => n.key), ['a']);
    expect(other.existsSync(), isTrue);
  });
}
