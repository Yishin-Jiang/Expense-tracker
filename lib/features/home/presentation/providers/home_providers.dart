import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/taipei_time.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/home_snapshot.dart';

final currentTaipeiDateProvider = Provider<DateTime>(
  (_) => toTaipeiTime(DateTime.now()),
);

final homeSnapshotProvider = StreamProvider.autoDispose<HomeSnapshot>((ref) {
  final today = ref.watch(currentTaipeiDateProvider);
  final range = taipeiMonthRange(today);

  return ref
      .watch(transactionRepositoryProvider)
      .watchTransactions(range)
      .map((transactions) => _buildSnapshot(transactions, today));
});

HomeSnapshot _buildSnapshot(
  List<TransactionRecord> transactions,
  DateTime today,
) {
  var monthExpense = 0;
  var monthIncome = 0;
  var todayExpense = 0;
  var todayIncome = 0;
  final todayTransactions = <TransactionRecord>[];

  for (final transaction in transactions) {
    final isExpense = transaction.type == TransactionType.expense;
    if (isExpense) {
      monthExpense += transaction.amount;
    } else {
      monthIncome += transaction.amount;
    }

    final localDate = toTaipeiTime(transaction.occurredAt);
    final isToday =
        localDate.year == today.year &&
        localDate.month == today.month &&
        localDate.day == today.day;
    if (!isToday) continue;

    todayTransactions.add(transaction);
    if (isExpense) {
      todayExpense += transaction.amount;
    } else {
      todayIncome += transaction.amount;
    }
  }

  return HomeSnapshot(
    monthExpense: monthExpense,
    monthIncome: monthIncome,
    todayExpense: todayExpense,
    todayIncome: todayIncome,
    todayTransactions: List.unmodifiable(todayTransactions),
    recentTransactions: List.unmodifiable(transactions.take(5)),
  );
}
