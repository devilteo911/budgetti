import 'package:uuid/uuid.dart';

/// An installment plan and everything derived from it.
///
/// Nothing about progress is stored: given the total, the number of rates and
/// the date of the first one, "how many are paid" is a function of today's
/// date. That keeps the row immutable after creation — no monthly bookkeeping
/// job, no drift between devices, and the same answer on the phone and the web
/// (`web/src/finance.ts installmentStatus` is the mirror of this file).
class Installment {
  final String id;
  final String userId;
  final String description;
  final double totalAmount;
  final int installmentCount;

  /// Date the first rate is charged; every later rate falls on the same
  /// day-of-month (clamped to short months).
  final DateTime startDate;
  final String? category;
  final String? accountId;

  Installment({
    required this.id,
    required this.userId,
    required this.description,
    required this.totalAmount,
    required this.installmentCount,
    required this.startDate,
    this.category,
    this.accountId,
  });

  /// Amount of a single rate. Guards a 0-count row (a corrupt/imported plan)
  /// rather than dividing by zero.
  double get amountPerInstallment =>
      installmentCount <= 0 ? 0 : totalAmount / installmentCount;

  /// Rates already charged as of [now]. The rate for the current month counts
  /// as paid once its due day has arrived.
  int paidCount([DateTime? now]) {
    if (installmentCount <= 0) return 0;
    final today = _dateOnly(now ?? DateTime.now());
    final start = _dateOnly(startDate);
    if (today.isBefore(start)) return 0;
    final elapsed = (today.year - start.year) * 12 + (today.month - start.month);
    final dueDay = _clampDay(today.year, today.month, start.day);
    final paid = today.day >= dueDay ? elapsed + 1 : elapsed;
    return paid.clamp(0, installmentCount);
  }

  int remainingCount([DateTime? now]) => installmentCount - paidCount(now);

  double paidAmount([DateTime? now]) => amountPerInstallment * paidCount(now);

  double remainingAmount([DateTime? now]) =>
      amountPerInstallment * remainingCount(now);

  /// 0..1 — how far through the plan we are.
  double progress([DateTime? now]) =>
      installmentCount <= 0 ? 0 : paidCount(now) / installmentCount;

  bool isActive([DateTime? now]) => remainingCount(now) > 0;

  /// Due date of the next unpaid rate, or null once the plan is settled.
  DateTime? nextDueDate([DateTime? now]) {
    final paid = paidCount(now);
    if (paid >= installmentCount) return null;
    return _addMonths(startDate, paid);
  }

  /// Due date of the last rate — when the plan is done.
  DateTime get endDate => _addMonths(startDate, installmentCount - 1);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static int _clampDay(int year, int month, int day) {
    final max = _daysInMonth(year, month);
    return day > max ? max : day;
  }

  /// [start] shifted by [months], keeping the day-of-month where the target
  /// month is long enough (31 Jan + 1 month = 28/29 Feb, not 3 Mar).
  static DateTime _addMonths(DateTime start, int months) {
    final total = start.month - 1 + months;
    final year = start.year + (total ~/ 12);
    final month = total % 12 + 1;
    return DateTime(year, month, _clampDay(year, month, start.day));
  }

  Installment copyWith({
    String? id,
    String? userId,
    String? description,
    double? totalAmount,
    int? installmentCount,
    DateTime? startDate,
    String? category,
    String? accountId,
  }) {
    return Installment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      installmentCount: installmentCount ?? this.installmentCount,
      startDate: startDate ?? this.startDate,
      category: category ?? this.category,
      accountId: accountId ?? this.accountId,
    );
  }

  factory Installment.fromJson(Map<String, dynamic> json) {
    return Installment(
      id: json['id']?.toString() ?? const Uuid().v4(),
      userId: json['user_id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      installmentCount: (json['installment_count'] as num?)?.toInt() ?? 1,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'].toString())
          : DateTime.now(),
      category: json['category']?.toString(),
      accountId: json['account_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        'total_amount': totalAmount,
        'installment_count': installmentCount,
        'start_date': startDate.toIso8601String(),
        'category': category,
        'account_id': accountId,
      };
}
