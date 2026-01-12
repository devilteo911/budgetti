import 'package:uuid/uuid.dart';

class BankConnection {
  final String id;
  final String userId;
  final String institutionId;
  final String institutionName;
  final String accountHolderName;
  final String accountNumberMasked;
  final String requisitionId;
  final String? walletId; // Which app wallet this syncs to
  final String status; // 'active', 'expired', 'error'
  final DateTime? lastSyncAt;
  final DateTime createdAt;
  final DateTime? accessValidUntil;

  BankConnection({
    required this.id,
    required this.userId,
    required this.institutionId,
    required this.institutionName,
    required this.accountHolderName,
    required this.accountNumberMasked,
    required this.requisitionId,
    this.walletId,
    required this.status,
    this.lastSyncAt,
    required this.createdAt,
    this.accessValidUntil,
  });

  factory BankConnection.fromJson(Map<String, dynamic> json) {
    return BankConnection(
      id: json['id']?.toString() ?? const Uuid().v4(),
      userId: json['user_id']?.toString() ?? '',
      institutionId: json['institution_id']?.toString() ?? '',
      institutionName: json['institution_name']?.toString() ?? '',
      accountHolderName: json['account_holder_name']?.toString() ?? '',
      accountNumberMasked: json['account_number_masked']?.toString() ?? '',
      requisitionId: json['requisition_id']?.toString() ?? '',
      walletId: json['wallet_id']?.toString(),
      status: json['status']?.toString() ?? 'active',
      lastSyncAt: json['last_sync_at'] != null 
          ? DateTime.tryParse(json['last_sync_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      accessValidUntil: json['access_valid_until'] != null
          ? DateTime.tryParse(json['access_valid_until'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'institution_id': institutionId,
      'institution_name': institutionName,
      'account_holder_name': accountHolderName,
      'account_number_masked': accountNumberMasked,
      'requisition_id': requisitionId,
      'wallet_id': walletId,
      'status': status,
      'last_sync_at': lastSyncAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'access_valid_until': accessValidUntil?.toIso8601String(),
    };
  }

  BankConnection copyWith({
    String? id,
    String? userId,
    String? institutionId,
    String? institutionName,
    String? accountHolderName,
    String? accountNumberMasked,
    String? requisitionId,
    String? walletId,
    String? status,
    DateTime? lastSyncAt,
    DateTime? createdAt,
    DateTime? accessValidUntil,
  }) {
    return BankConnection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      institutionId: institutionId ?? this.institutionId,
      institutionName: institutionName ?? this.institutionName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumberMasked: accountNumberMasked ?? this.accountNumberMasked,
      requisitionId: requisitionId ?? this.requisitionId,
      walletId: walletId ?? this.walletId,
      status: status ?? this.status,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      createdAt: createdAt ?? this.createdAt,
      accessValidUntil: accessValidUntil ?? this.accessValidUntil,
    );
  }

  bool get isExpired {
    if (accessValidUntil == null) return false;
    return DateTime.now().isAfter(accessValidUntil!);
  }

  bool get isActive => status == 'active' && !isExpired;
}
