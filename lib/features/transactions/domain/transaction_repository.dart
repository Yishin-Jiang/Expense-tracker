import 'transaction.dart';

abstract interface class TransactionRepository {
  Stream<List<TransactionRecord>> watchTransactions(TransactionDateRange range);
  Future<TransactionRecord?> getTransaction(int id);
  Future<TransactionRecord> createTransaction(TransactionInput input);
  Future<TransactionRecord> updateTransaction(int id, TransactionInput input);
  Future<void> deleteTransaction(int id);
  Stream<DailyTransactionSummary> watchDailySummary(DateTime date);
}
