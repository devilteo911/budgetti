import 'dart:convert';

import 'package:budgetti/core/services/google_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

/// A single fetched email from Banca Widiba, reduced to what the parser needs.
class WidibaEmail {
  final String id;
  final String subject;
  final String body;
  final DateTime receivedAt;

  const WidibaEmail({
    required this.id,
    required this.subject,
    required this.body,
    required this.receivedAt,
  });
}

/// Read-only Gmail access scoped to messages from widiba@widiba.it.
class GmailService {
  final GoogleAuthService _auth;

  GmailService(this._auth);

  static const String _sender = 'widiba@widiba.it';

  /// Fetches recent Widiba emails. Provide either [days] (relative window) or
  /// [after] (absolute lower bound); [after] wins when both are set.
  /// [excludeIds] lets the caller skip messages already imported, avoiding a
  /// `messages.get` round-trip for known ids.
  Future<List<WidibaEmail>> fetchRecent({
    int days = 7,
    DateTime? after,
    Set<String> excludeIds = const {},
    int maxResults = 100,
  }) async {
    final client = await _auth.authenticatedClient();
    if (client == null) {
      debugPrint('GmailService: no authenticated client (not signed in?)');
      return [];
    }

    try {
      final api = gmail.GmailApi(client);
      final query = _buildQuery(days: days, after: after);

      final list = await api.users.messages.list(
        'me',
        q: query,
        maxResults: maxResults,
      );

      final refs = list.messages ?? const [];
      final result = <WidibaEmail>[];

      for (final ref in refs) {
        final id = ref.id;
        if (id == null || excludeIds.contains(id)) continue;

        final full = await api.users.messages.get('me', id, format: 'full');
        final email = _toEmail(id, full);
        if (email != null) result.add(email);
      }

      return result;
    } catch (e, s) {
      debugPrint('GmailService.fetchRecent failed: $e\n$s');
      return [];
    } finally {
      client.close();
    }
  }

  String _buildQuery({required int days, DateTime? after}) {
    final buffer = StringBuffer('from:$_sender');
    if (after != null) {
      final y = after.year.toString().padLeft(4, '0');
      final m = after.month.toString().padLeft(2, '0');
      final d = after.day.toString().padLeft(2, '0');
      buffer.write(' after:$y/$m/$d');
    } else {
      buffer.write(' newer_than:${days}d');
    }
    return buffer.toString();
  }

  WidibaEmail? _toEmail(String id, gmail.Message msg) {
    final payload = msg.payload;
    if (payload == null) return null;

    final subject = _header(payload, 'Subject') ?? '';
    final body = _extractBody(payload);
    if (body.isEmpty) return null;

    final receivedAt = _receivedAt(msg);

    return WidibaEmail(
      id: id,
      subject: subject,
      body: body,
      receivedAt: receivedAt,
    );
  }

  String? _header(gmail.MessagePart part, String name) {
    final headers = part.headers;
    if (headers == null) return null;
    for (final h in headers) {
      if ((h.name ?? '').toLowerCase() == name.toLowerCase()) return h.value;
    }
    return null;
  }

  DateTime _receivedAt(gmail.Message msg) {
    final internal = msg.internalDate;
    if (internal != null) {
      final ms = int.tryParse(internal);
      if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return DateTime.now();
  }

  /// Walks the MIME tree preferring text/plain; falls back to stripped HTML.
  String _extractBody(gmail.MessagePart part) {
    final plain = _findPart(part, 'text/plain');
    if (plain != null) return plain;

    final html = _findPart(part, 'text/html');
    if (html != null) return _stripHtml(html);

    return '';
  }

  String? _findPart(gmail.MessagePart part, String mime) {
    if ((part.mimeType ?? '').toLowerCase() == mime) {
      final data = part.body?.data;
      if (data != null && data.isNotEmpty) return _decode(data);
    }
    for (final child in part.parts ?? const <gmail.MessagePart>[]) {
      final found = _findPart(child, mime);
      if (found != null) return found;
    }
    return null;
  }

  String _decode(String data) {
    try {
      final normalized =
          base64.normalize(data.replaceAll('-', '+').replaceAll('_', '/'));
      return utf8.decode(base64.decode(normalized), allowMalformed: true);
    } catch (e) {
      debugPrint('GmailService._decode failed: $e');
      return '';
    }
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&euro;', '€')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
