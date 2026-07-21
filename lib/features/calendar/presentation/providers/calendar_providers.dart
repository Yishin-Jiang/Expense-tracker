import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/taipei_time.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/calendar_month_snapshot.dart';

final calendarTodayProvider = Provider<DateTime>(
  (_) => toTaipeiTime(DateTime.now()),
);

final calendarMonthProvider = StreamProvider.autoDispose
    .family<CalendarMonthSnapshot, DateTime>((ref, month) {
      final normalizedMonth = DateTime(month.year, month.month);
      final range = taipeiMonthRange(normalizedMonth);
      return ref
          .watch(transactionRepositoryProvider)
          .watchTransactions(range)
          .map((transactions) => _buildMonth(normalizedMonth, transactions));
    });

CalendarMonthSnapshot _buildMonth(
  DateTime month,
  List<TransactionRecord> transactions,
) {
  var income = 0;
  var expense = 0;
  final byDay = <int, List<TransactionRecord>>{};

  for (final transaction in transactions) {
    final localDate = toTaipeiTime(transaction.occurredAt);
    byDay.putIfAbsent(localDate.day, () => []).add(transaction);
    if (transaction.type == TransactionType.income) {
      income += transaction.amount;
    } else {
      expense += transaction.amount;
    }
  }

  final days = <int, CalendarDaySummary>{};
  for (final entry in byDay.entries) {
    var dayIncome = 0;
    var dayExpense = 0;
    for (final transaction in entry.value) {
      if (transaction.type == TransactionType.income) {
        dayIncome += transaction.amount;
      } else {
        dayExpense += transaction.amount;
      }
    }
    days[entry.key] = CalendarDaySummary(
      date: DateTime(month.year, month.month, entry.key),
      income: dayIncome,
      expense: dayExpense,
      transactions: List.unmodifiable(entry.value),
    );
  }

  return CalendarMonthSnapshot(
    month: month,
    income: income,
    expense: expense,
    days: Map.unmodifiable(days),
  );
}
