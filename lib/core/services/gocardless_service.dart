import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:budgetti/core/services/persistence_service.dart';

class GocardlessService {
  static const String baseUrl = 'https://bankaccountdata.gocardless.com/api/v2';
  final PersistenceService _persistence;
  
  String? _accessToken;
  DateTime? _tokenExpiresAt;

  GocardlessService(this._persistence);

  // ============ AUTHENTICATION ============

  Future<void> createAccessToken(String secretId, String secretKey) async {
    final url = Uri.parse('$baseUrl/token/new/');
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'secret_id': secretId,
        'secret_key': secretKey,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      _accessToken = data['access'];
      _tokenExpiresAt = DateTime.now().add(const Duration(hours: 24));
      
      // Store tokens securely
      await _persistence.setGocardlessAccessToken(_accessToken!);
      await _persistence.setGocardlessRefreshToken(data['refresh']);
      await _persistence.setGocardlessSecretId(secretId);
      await _persistence.setGocardlessSecretKey(secretKey);
    } else {
      throw Exception('Failed to create access token: ${response.body}');
    }
  }

  Future<void> refreshAccessToken() async {
    final refreshToken = _persistence.getGocardlessRefreshToken();
    if (refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final url = Uri.parse('$baseUrl/token/refresh/');
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access'];
      _tokenExpiresAt = DateTime.now().add(const Duration(hours: 24));
      
      await _persistence.setGocardlessAccessToken(_accessToken!);
    } else {
      throw Exception('Failed to refresh token: ${response.body}');
    }
  }

  Future<String> _getValidToken() async {
    // Try to load from persistence if not in memory
    if (_accessToken == null) {
      _accessToken = _persistence.getGocardlessAccessToken();
    }

    // Check if token is expired or about to expire
    if (_tokenExpiresAt == null || DateTime.now().isAfter(_tokenExpiresAt!.subtract(const Duration(minutes: 5)))) {
      await refreshAccessToken();
    }

    if (_accessToken == null) {
      throw Exception('No access token available. Please authenticate first.');
    }

    return _accessToken!;
  }

  // ============ INSTITUTIONS ============

  Future<List<Map<String, dynamic>>> getInstitutions(String country) async {
    final token = await _getValidToken();
    final url = Uri.parse('$baseUrl/institutions/?country=$country');
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch institutions: ${response.body}');
    }
  }

  // ============ END USER AGREEMENTS ============

  Future<String> createEndUserAgreement({
    required String institutionId,
    int maxHistoricalDays = 90,
    int accessValidForDays = 90,
  }) async {
    final token = await _getValidToken();
    final url = Uri.parse('$baseUrl/agreements/enduser/');
    
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'institution_id': institutionId,
        'max_historical_days': maxHistoricalDays,
        'access_valid_for_days': accessValidForDays,
        'access_scope': ['balances', 'details', 'transactions'],
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['id'];
    } else {
      throw Exception('Failed to create end user agreement: ${response.body}');
    }
  }

  // ============ REQUISITIONS ============

  Future<Map<String, dynamic>> createRequisition({
    required String institutionId,
    required String redirect,
    String? agreementId,
    String? reference,
  }) async {
    final token = await _getValidToken();
    final url = Uri.parse('$baseUrl/requisitions/');
    
    final body = {
      'redirect': redirect,
      'institution_id': institutionId,
    };
    
    if (agreementId != null) body['agreement'] = agreementId;
    if (reference != null) body['reference'] = reference;

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create requisition: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getRequisition(String requisitionId) async {
    final token = await _getValidToken();
    final url = Uri.parse('$baseUrl/requisitions/$requisitionId/');
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch requisition: ${response.body}');
    }
  }

  Future<void> deleteRequisition(String requisitionId) async {
    final token = await _getValidToken();
    final url = Uri.parse('$baseUrl/requisitions/$requisitionId/');
    
    final response = await http.delete(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete requisition: ${response.body}');
    }
  }

  // ============ ACCOUNTS ============

  Future<Map<String, dynamic>> getAccountDetails(String accountId) async {
    final token = await _getValidToken();
    final url = Uri.parse('$baseUrl/accounts/$accountId/details/');
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch account details: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getAccountBalances(String accountId) async {
    final token = await _getValidToken();
    final url = Uri.parse('$baseUrl/accounts/$accountId/balances/');
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch account balances: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getAccountTransactions(
    String accountId, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final token = await _getValidToken();
    var urlStr = '$baseUrl/accounts/$accountId/transactions/';
    
    final queryParams = <String, String>{};
    if (dateFrom != null) {
      queryParams['date_from'] = dateFrom.toIso8601String().split('T')[0];
    }
    if (dateTo != null) {
      queryParams['date_to'] = dateTo.toIso8601String().split('T')[0];
    }
    
    if (queryParams.isNotEmpty) {
      urlStr += '?${Uri(queryParameters: queryParams).query}';
    }
    
    final url = Uri.parse(urlStr);
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch account transactions: ${response.body}');
    }
  }
}
