import '../../transactions/domain/transaction.dart';

class AnalysisMonthSnapshot {
  const AnalysisMonthSnapshot({
    required this.month,
    required this.income,
    required this.expense,
    required this.previousIncome,
    required this.previousExpense,
    required this.dailyExpenses,
    required this.categoryExpenses,
    required this.channelExpenses,
    required this.transactions,
  });

  final DateTime month;
  final int income;
  final int expense;
  final int previousIncome;
  final int previousExpense;
  final Map<int, int> dailyExpenses;
  final Map<int, int> categoryExpenses;
  final Map<int?, int> channelExpenses;
  final List<TransactionRecord> transactions;

  int get balance => income - expense;
  int get previousBalance => previousIncome - previousExpense;

  double? get expenseChangePercent {
    if (previousExpense == 0) return null;
    return (expense - previousExpense) / previousExpense * 100;
  }

  List<TransactionRecord> transactionsForCategory(int categoryId) =>
      transactionsForCategories({categoryId});

  List<TransactionRecord> transactionsForCategories(Iterable<int> categoryIds) {
    final ids = categoryIds.toSet();
    return transactions
        .where(
          (item) =>
              item.type == TransactionType.expense &&
              ids.contains(item.categoryId),
        )
        .toList(growable: false);
  }
}
