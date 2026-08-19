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
    final file = File('${dir.path}/$_bufferFile');
    if (!await file.exists()) return const [];
    final contents = await file.readAsString();
    // Delete only after a successful decode: the buffer is the only copy of
    // the captured pushes, and the listener's next write replaces the file
    // wholesale — so a corrupt buffer left in place self-heals instead of
    // being silently discarded.
    if (contents.isEmpty) {
      try {
        await file.delete();
      } catch (_) {}
      return const [];
    }
    try {
      final list = jsonDecode(contents) as List<dynamic>;
      final parsed = list
          .cast<Map<String, dynamic>>()
          .map(RawNotification.fromJson)
          .toList();
      try {
        await file.delete();
      } catch (_) {}
      return parsed;
    } catch (_) {
      return const [];
    }
  }

  Future<bool> isAccessEnabled() async =>
      await _channel.invokeMethod<bool>('isAccessEnabled') ?? false;

  Future<void> openSettings() async => _channel.invokeMethod('openSettings');
}
