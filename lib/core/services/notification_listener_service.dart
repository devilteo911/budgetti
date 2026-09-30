import 'dart:convert';
import 'dart:io';

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

  /// Takes everything out of the listener's [buffer] file, exactly once.
  ///
  /// The buffer is the only copy of a captured push, and launch, resume,
  /// pull-to-refresh and the background task all drain it. Reading it in place
  /// and deleting it afterwards let a push the listener appended in between be
  /// deleted unread, and let two drains both read the same file. So the buffer
  /// is claimed first by renaming it to `<buffer>.draining` — atomic, so only
  /// one caller wins and the listener's next push starts a fresh buffer — and
  /// only then read and deleted.
  ///
  /// A claim that is still there was left by a drain that died before deleting
  /// it: those pushes exist nowhere else, so it is finished first. A corrupt
  /// claim or buffer cannot be recovered and is dropped rather than retried
  /// forever (the listener writes atomically, so this is not expected).
  ///
  /// ponytail: drains inside one isolate are queued, which makes "exactly one
  /// gets the pushes" deterministic there. Across isolates only the rename
  /// protects, and a drain that starts while another isolate's claim is still
  /// in flight may read it too: harmless, capture dedups by content hash.
  static Future<List<RawNotification>> drain(File buffer) {
    final run = _lane.then((_) => _drain(buffer));
    _lane = run.then((_) {}, onError: (_) {});
    return run;
  }

  static Future<void> _lane = Future.value();

  static Future<List<RawNotification>> _drain(File buffer) async {
    final claim = File('${buffer.path}.draining');
    final out = await _takeClaim(claim);
    try {
      await buffer.rename(claim.path);
    } on FileSystemException {
      return out; // no buffer, or another drain claimed it first
    }
    return [...out, ...await _takeClaim(claim)];
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
