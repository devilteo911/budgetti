import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class EnableBankingService {
  // Supabase project URL — must match the one in main.dart
  static const _supabaseUrl = 'https://weothkvnaixuhmrxyjoo.supabase.co';

  String get _baseUrl => '$_supabaseUrl/functions/v1/bank-sync';

  Map<String, String> get _headers {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: _headers,
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 400) {
      final error = data is Map ? data['error'] ?? response.body : response.body;
      throw Exception('EnableBanking error: $error');
    }

    if (data is Map<String, dynamic>) return data;
    return {'data': data};
  }

  /// List available banks for a given country.
  Future<List<Map<String, dynamic>>> listBanks({String country = 'IT'}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl?action=list_banks&country=$country'),
      headers: _headers,
    );

    if (response.statusCode >= 400) {
      throw Exception('Failed to list banks: ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  /// Create a bank authorization session.
  /// Returns a map with 'url' (redirect URL) and session info.
  Future<Map<String, dynamic>> createSession({
    required String bankName,
    required String country,
    String? iban,
  }) async {
    final validUntil = DateTime.now()
        .add(const Duration(days: 90))
        .toUtc()
        .toIso8601String();

    final accessScope = <String, dynamic>{
      'valid_until': validUntil,
      'balances': {
        'accounts': [
          if (iban != null) {'iban': iban},
        ],
      },
      'transactions': {
        'accounts': [
          if (iban != null) {'iban': iban},
        ],
      },
    };

    final result = await _post({
      'action': 'create_session',
      'access': accessScope,
      'aspsp': {'name': bankName, 'country': country},
      'state': DateTime.now().millisecondsSinceEpoch.toString(),
      'redirect_url': 'https://budgetti.app/callback',
      'psu_type': 'personal',
    });

    // EnableBanking returns url field for redirect
    final authUrl = result['url'] as String?;
    final sessionId = result['session_id'] as String?;

    debugPrint('EnableBanking session created: id=$sessionId');

    return {
      'url': authUrl,
      'session_id': sessionId,
      ...result,
    };
  }

  /// Get session status and accounts after user completes bank auth.
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl?action=get_session&session_id=$sessionId'),
      headers: _headers,
    );

    if (response.statusCode >= 400) {
      throw Exception('Failed to get session: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Fetch transactions for a bank account.
  Future<List<Map<String, dynamic>>> getTransactions(
    String accountId, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final params = <String, String>{
      'action': 'get_transactions',
      'account_id': accountId,
    };
    if (dateFrom != null) {
      params['date_from'] =
          '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
    }
    if (dateTo != null) {
      params['date_to'] =
          '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode >= 400) {
      throw Exception('Failed to get transactions: ${response.body}');
    }

    final data = jsonDecode(response.body);

    // EnableBanking returns { "transactions": { "booked": [...], "pending": [...] } }
    if (data is Map && data.containsKey('transactions')) {
      final transactions = data['transactions'] as Map<String, dynamic>;
      final booked = transactions['booked'] as List? ?? [];
      return List<Map<String, dynamic>>.from(booked);
    }

    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }

    return [];
  }

  /// Fetch balance for a bank account.
  Future<Map<String, dynamic>> getBalances(String accountId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl?action=get_balances&account_id=$accountId'),
      headers: _headers,
    );

    if (response.statusCode >= 400) {
      throw Exception('Failed to get balances: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
