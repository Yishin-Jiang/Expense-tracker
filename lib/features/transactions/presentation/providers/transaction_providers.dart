import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../data/drift_transaction_repository.dart';
import '../../domain/transaction.dart';
import '../../domain/transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => DriftTransactionRepository(ref.watch(databaseProvider)),
);

final transactionsForRangeProvider = StreamProvider.autoDispose
    .family<List<TransactionRecord>, TransactionDateRange>(
      (ref, range) =>
          ref.watch(transactionRepositoryProvider).watchTransactions(range),
    );

final transactionByIdProvider = FutureProvider.autoDispose
    .family<TransactionRecord?, int>(
      (ref, id) => ref.watch(transactionRepositoryProvider).getTransaction(id),
    );

final dailyTransactionSummaryProvider = StreamProvider.autoDispose
    .family<DailyTransactionSummary, DateTime>(
      (ref, date) =>
          ref.watch(transactionRepositoryProvider).watchDailySummary(date),
    );
