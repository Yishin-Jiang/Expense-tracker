import '../../transactions/domain/transaction.dart';

class HomeSnapshot {
  const HomeSnapshot({
    required this.monthExpense,
    required this.monthIncome,
    required this.todayExpense,
    required this.todayIncome,
    required this.todayTransactions,
    required this.recentTransactions,
  });

  final int monthExpense;
  final int monthIncome;
  final int todayExpense;
  final int todayIncome;
  final List<TransactionRecord> todayTransactions;
  final List<TransactionRecord> recentTransactions;

  int get balance => monthIncome - monthExpense;
  int get todayCount => todayTransactions.length;
}
