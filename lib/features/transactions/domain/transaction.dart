enum TransactionType { expense, income }

enum TransactionSource { manual, subscription }

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.categoryId,
    required this.type,
    required this.amount,
    required this.occurredAt,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.channelId,
    this.note,
    this.deletedAt,
  });

  final int id;
  final int categoryId;
  final int? channelId;
  final TransactionType type;
  final int amount;
  final DateTime occurredAt;
  final String? note;
  final TransactionSource source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

class TransactionInput {
  const TransactionInput({
    required this.categoryId,
    required this.type,
    required this.amount,
    required this.occurredAt,
    this.channelId,
    this.note,
    this.source = TransactionSource.manual,
  });

  final int categoryId;
  final int? channelId;
  final TransactionType type;
  final int amount;
  final DateTime occurredAt;
  final String? note;
  final TransactionSource source;

  void validate() {
    if (categoryId <= 0) {
      throw const TransactionValidationException('請選擇有效的類別');
    }
    if (channelId != null && channelId! <= 0) {
      throw const TransactionValidationException('購物管道無效');
    }
    if (amount <= 0) {
      throw const TransactionValidationException('金額必須大於 0');
    }
    if (note != null && note!.trim().length > 500) {
      throw const TransactionValidationException('備註不能超過 500 個字元');
    }
  }
}

class TransactionValidationException implements Exception {
  const TransactionValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class DailyTransactionSummary {
  const DailyTransactionSummary({
    required this.date,
    required this.income,
    required this.expense,
    required this.transactionCount,
  });

  final DateTime date;
  final int income;
  final int expense;
  final int transactionCount;
  int get balance => income - expense;
}

typedef TransactionDateRange = ({DateTime start, DateTime end});
