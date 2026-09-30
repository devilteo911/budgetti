import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// A Revolut push notification captured by the native
/// [RevolutNotificationListener], awaiting parsing into a pending draft.
class RawNotification {
  final String key;
  final String title;
  final String text;
  final DateTime when;

  const RawNotification({
    required this.key,
    required this.title,
    required this.text,
    required this.when,
  });

  factory RawNotification.fromJson(Map<String, dynamic> json) => RawNotification(
        key: json['key'] as String? ?? '',
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
        when: DateTime.fromMillisecondsSinceEpoch(
          (json['when'] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
      );
}

/// Bridges the native Android NotificationListenerService.
///
/// Captured notifications are buffered to a file by the listener; [pull] reads
/// and clears it. Reading the file directly (not via a MethodChannel) keeps
/// pulls working from the workmanager background isolate, where the
/// MainActivity channel handler isn't alive. The channel is reserved for the
/// foreground-only permission check and settings deep-link.
class NotificationListenerService {
  const NotificationListenerService();

  static const _channel = MethodChannel('budgetti/notifications');
  static const _bufferFile = 'revolut_notifications.json';

  Future<List<RawNotification>> pull() async {
    final dir = await getApplicationSupportDirectory();
    return drain(File('${dir.path}/$_bufferFile'));
  }

  /// Takes everything out of the listener's [buffer] file.
  ///
  /// The buffer is the only copy of a captured push, and launch, resume,
  /// pull-to-refresh and the background task all drain it. Reading it in place
  /// and deleting it afterwards let a push the listener appended in between be
  /// deleted unread. So the buffer is claimed first by renaming it — atomic, so
  /// only one caller wins and the listener's next push starts a fresh buffer —
  /// and only then read and deleted.
  ///
  /// Every drain claims under its OWN unique name (the buffer's name plus
  /// `.draining.` and a timestamp-and-random suffix). A shared name would let a second drain's rename land on a first
  /// drain's claim it has not read yet: POSIX rename replaces the target, and
  /// those pushes would be destroyed unread.
  ///
  /// Every claim already in the directory is finished first, oldest first: it was
  /// left by a drain that died before deleting it, or belongs to one still
  /// reading it in another isolate. Those pushes exist nowhere else. A corrupt
  /// claim or buffer cannot be recovered and is dropped rather than retried
  /// forever (the listener writes atomically, so this is not expected).
  ///
  /// ponytail: what this does not cover. A drain returns the pushes AFTER
  /// deleting their claim, so a process killed before capture has inserted the
  /// drafts loses that batch; a claim still held by a live drain in another
  /// isolate can be read twice, which is harmless because capture dedups by
  /// content id. Deleting the claim only after the insert would close the first,
  /// at the price of re-reading on every failure. Drains within one isolate are
  /// queued, so "exactly one gets the pushes" is deterministic there.
  static Future<List<RawNotification>> drain(File buffer) {
    final run = _lane.then((_) => _drain(buffer));
    _lane = run.then((_) {}, onError: (_) {});
    return run;
  }

  static Future<void> _lane = Future.value();

  /// [drain] without the in-isolate queue and with a hook at each stage
  /// ('recovered', 'claimed'), to replay the interleavings of two drains in
  /// different isolates, which the queue hides from a single-isolate test.
  @visibleForTesting
  static Future<List<RawNotification>> drainInterleaved(
    File buffer,
    Future<void> Function(String stage) pause,
  ) =>
      _drain(buffer, pause);

  static Future<List<RawNotification>> _drain(
    File buffer, [
    Future<void> Function(String stage)? pause,
  ]) async {
    final out = <RawNotification>[];
    for (final claim in await _claimsBeside(buffer)) {
      out.addAll(await _takeClaim(claim));
    }
    await pause?.call('recovered');

    final mine = File('${buffer.path}.draining.'
        '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}');
    try {
      await buffer.rename(mine.path);
    } on FileSystemException {
      return out; // no buffer, or another drain claimed it first
    }
    await pause?.call('claimed');
    return [...out, ...await _takeClaim(mine)];
  }

  static final _random = Random();

  /// Claims sitting next to [buffer], oldest first (the names embed the time).
  static Future<List<File>> _claimsBeside(File buffer) async {
    final prefix = '${buffer.uri.pathSegments.last}.draining';
    if (!await buffer.parent.exists()) return const [];
    final claims = [
      await for (final e in buffer.parent.list())
        if (e is File && e.uri.pathSegments.last.startsWith(prefix)) e,
    ];
    return claims..sort((a, b) => a.path.compareTo(b.path));
  }

  static Future<List<RawNotification>> _takeClaim(File claim) async {
    if (!await claim.exists()) return const [];
    try {
      final contents = await claim.readAsString();
      if (contents.isEmpty) return const [];
      return (jsonDecode(contents) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(RawNotification.fromJson)
          .toList();
    } catch (_) {
      return const []; // corrupt: dropped with the file below
    } finally {
      try {
        await claim.delete();
      } catch (_) {}
    }
  }

  Future<bool> isAccessEnabled() async =>
      await _channel.invokeMethod<bool>('isAccessEnabled') ?? false;

  Future<void> openSettings() async => _channel.invokeMethod('openSettings');
}
