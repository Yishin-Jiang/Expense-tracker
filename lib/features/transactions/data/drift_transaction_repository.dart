import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/utils/taipei_time.dart';
import '../domain/transaction.dart';
import '../domain/transaction_repository.dart';

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(this._database);
  final db.AppDatabase _database;

  @override
  Stream<List<TransactionRecord>> watchAllTransactions() {
    return _database.transactionDao.watchAllTransactions().map(
      (items) => items.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Stream<List<TransactionRecord>> watchTransactions(
    TransactionDateRange range,
  ) {
    return _database.transactionDao
        .watchTransactions(start: range.start, end: range.end)
        .map((items) => items.map(_toDomain).toList(growable: false));
  }

  @override
  Future<TransactionRecord?> getTransaction(int id) async {
    final item = await _database.transactionDao.getTransaction(id);
    return item == null ? null : _toDomain(item);
  }

  @override
  Future<TransactionRecord> createTransaction(TransactionInput input) async {
    input.validate();
    final id = await _database.transactionDao.createTransaction(
      db.TransactionsCompanion.insert(
        categoryId: input.categoryId,
        channelId: Value(input.channelId),
        type: input.type.name,
        amount: input.amount,
        occurredAt: input.occurredAt.toUtc(),
        note: Value(_normalizedNote(input.note)),
        source: Value(input.source.name),
      ),
    );
    return _getRequired(id);
  }

  @override
  Future<TransactionRecord> updateTransaction(
    int id,
    TransactionInput input,
  ) async {
    input.validate();
    final updated = await _database.transactionDao.updateTransactionFields(
      id,
      db.TransactionsCompanion(
        categoryId: Value(input.categoryId),
        channelId: Value(input.channelId),
        type: Value(input.type.name),
        amount: Value(input.amount),
        occurredAt: Value(input.occurredAt.toUtc()),
        note: Value(_normalizedNote(input.note)),
        source: Value(input.source.name),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    if (updated != 1) throw StateError('找不到交易 $id');
    return _getRequired(id);
  }

  @override
  Future<void> deleteTransaction(int id) async {
    if (await _database.transactionDao.softDeleteTransaction(id) != 1) {
      throw StateError('找不到交易 $id');
    }
  }

  @override
  Stream<DailyTransactionSummary> watchDailySummary(DateTime date) {
    final range = taipeiDayRange(date);
    return watchTransactions(range).map((items) {
      var income = 0;
      var expense = 0;
      for (final item in items) {
        if (item.type == TransactionType.income) {
          income += item.amount;
        } else {
          expense += item.amount;
        }
      }
      return DailyTransactionSummary(
        date: DateTime(date.year, date.month, date.day),
        income: income,
        expense: expense,
        transactionCount: items.length,
      );
    });
  }

  Future<TransactionRecord> _getRequired(int id) async {
    final item = await getTransaction(id);
    if (item == null) throw StateError('找不到交易 $id');
    return item;
  }

  TransactionRecord _toDomain(db.TransactionEntry item) => TransactionRecord(
    id: item.id,
    categoryId: item.categoryId,
    channelId: item.channelId,
    type: TransactionType.values.byName(item.type),
    amount: item.amount,
    occurredAt: item.occurredAt.toUtc(),
    note: item.note,
    source: TransactionSource.values.byName(item.source),
    createdAt: item.createdAt.toUtc(),
    updatedAt: item.updatedAt.toUtc(),
    deletedAt: item.deletedAt?.toUtc(),
  );

  String? _normalizedNote(String? note) {
    final normalized = note?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
