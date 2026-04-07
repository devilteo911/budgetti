import 'package:budgetti/models/transaction.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Maps EnableBanking API transaction JSON to app Transaction objects.
class BankTransactionMapper {
  /// Map a single EnableBanking transaction to an app Transaction.
  static Transaction? mapTransaction(
    Map<String, dynamic> json,
    String accountId,
  ) {
    try {
      // Parse amount
      final amountData = json['transactionAmount'] as Map<String, dynamic>?;
      if (amountData == null) return null;

      final amount = double.tryParse(amountData['amount']?.toString() ?? '');
      if (amount == null) return null;

      // Parse date (bookingDate preferred, fallback to valueDate)
      final dateStr = (json['bookingDate'] ?? json['valueDate'])?.toString();
      if (dateStr == null) return null;

      final date = DateTime.tryParse(dateStr);
      if (date == null) return null;

      // Determine type from amount sign
      final type = amount < 0 ? 'expense' : 'income';

      // Build description from available fields
      final remittance =
          (json['remittanceInformationUnstructured'] ?? '').toString().trim();
      final creditor = (json['creditorName'] ?? '').toString().trim();
      final debtor = (json['debtorName'] ?? '').toString().trim();

      String description;
      if (remittance.isNotEmpty) {
        description = remittance;
      } else if (amount < 0 && creditor.isNotEmpty) {
        description = creditor;
      } else if (amount >= 0 && debtor.isNotEmpty) {
        description = debtor;
      } else {
        description = creditor.isNotEmpty ? creditor : debtor;
      }

      // Use bank's transaction ID or generate one
      final id = json['transactionId']?.toString() ?? const Uuid().v4();

      return Transaction(
        id: id,
        accountId: accountId,
        amount: amount,
        date: date,
        description: description,
        category: '',
        type: type,
        tags: const [],
      );
    } catch (e) {
      debugPrint('Failed to map bank transaction: $e');
      return null;
    }
  }

  /// Map a list of EnableBanking transactions, skipping any that fail to parse.
  static List<Transaction> mapTransactions(
    List<Map<String, dynamic>> rawTransactions,
    String accountId,
  ) {
    final results = <Transaction>[];
    for (final raw in rawTransactions) {
      final tx = mapTransaction(raw, accountId);
      if (tx != null) results.add(tx);
    }
    return results;
  }

  /// Extract the bank's unique transaction ID for dedup.
  static String? extractBankTransactionId(Map<String, dynamic> json) {
    return json['transactionId']?.toString();
  }
}
