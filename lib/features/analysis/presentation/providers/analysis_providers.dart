import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/taipei_time.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/analysis_month_snapshot.dart';

final analysisTodayProvider = Provider<DateTime>(
  (_) => toTaipeiTime(DateTime.now()),
);

final analysisMonthProvider = StreamProvider.autoDispose
    .family<AnalysisMonthSnapshot, DateTime>((ref, month) {
      final currentMonth = DateTime(month.year, month.month);
      final previousMonth = DateTime(month.year, month.month - 1);
      final previousRange = taipeiMonthRange(previousMonth);
      final currentRange = taipeiMonthRange(currentMonth);
      final range = (start: previousRange.start, end: currentRange.end);

      return ref
          .watch(transactionRepositoryProvider)
          .watchTransactions(range)
          .map(
            (transactions) =>
                _buildSnapshot(currentMonth, previousMonth, transactions),
          );
    });

AnalysisMonthSnapshot _buildSnapshot(
  DateTime currentMonth,
  DateTime previousMonth,
  List<TransactionRecord> transactions,
) {
  var income = 0;
  var expense = 0;
  var previousIncome = 0;
  var previousExpense = 0;
  final dailyExpenses = <int, int>{};
  final categoryExpenses = <int, int>{};
  final channelExpenses = <int?, int>{};
  final currentTransactions = <TransactionRecord>[];

  for (final transaction in transactions) {
    final date = toTaipeiTime(transaction.occurredAt);
    final isCurrent =
        date.year == currentMonth.year && date.month == currentMonth.month;
    final isPrevious =
        date.year == previousMonth.year && date.month == previousMonth.month;

    if (isPrevious) {
      if (transaction.type == TransactionType.income) {
        previousIncome += transaction.amount;
      } else {
        previousExpense += transaction.amount;
      }
      continue;
    }
    if (!isCurrent) continue;

    currentTransactions.add(transaction);
    if (transaction.type == TransactionType.income) {
      income += transaction.amount;
      continue;
    }

    expense += transaction.amount;
    dailyExpenses.update(
      date.day,
      (value) => value + transaction.amount,
      ifAbsent: () => transaction.amount,
    );
    categoryExpenses.update(
      transaction.categoryId,
      (value) => value + transaction.amount,
      ifAbsent: () => transaction.amount,
    );
    channelExpenses.update(
      transaction.channelId,
      (value) => value + transaction.amount,
      ifAbsent: () => transaction.amount,
    );
  }

  return AnalysisMonthSnapshot(
    month: currentMonth,
    income: income,
    expense: expense,
    previousIncome: previousIncome,
    previousExpense: previousExpense,
    dailyExpenses: Map.unmodifiable(dailyExpenses),
    categoryExpenses: Map.unmodifiable(categoryExpenses),
    channelExpenses: Map.unmodifiable(channelExpenses),
    transactions: List.unmodifiable(currentTransactions),
  );
}
