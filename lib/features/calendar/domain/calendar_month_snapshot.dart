import '../../transactions/domain/transaction.dart';

class CalendarDaySummary {
  const CalendarDaySummary({
    required this.date,
    required this.income,
    required this.expense,
    required this.transactions,
  });

  final DateTime date;
  final int income;
  final int expense;
  final List<TransactionRecord> transactions;

  int get balance => income - expense;
  int get transactionCount => transactions.length;
}

class CalendarMonthSnapshot {
  const CalendarMonthSnapshot({
    required this.month,
    required this.income,
    required this.expense,
    required this.days,
  });

  final DateTime month;
  final int income;
  final int expense;
  final Map<int, CalendarDaySummary> days;

  int get balance => income - expense;

  CalendarDaySummary summaryFor(DateTime date) =>
      days[date.day] ??
      CalendarDaySummary(
        date: DateTime(date.year, date.month, date.day),
        income: 0,
        expense: 0,
        transactions: const [],
      );
}
