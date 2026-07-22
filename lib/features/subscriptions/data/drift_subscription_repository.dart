import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/utils/taipei_time.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/subscription.dart';
import '../domain/subscription_repository.dart';

class DriftSubscriptionRepository implements SubscriptionRepository {
  DriftSubscriptionRepository(this._database);
  final db.AppDatabase _database;

  @override
  Stream<List<SubscriptionRecord>> watchSubscriptions() {
    return _database.subscriptionDao.watchAllSubscriptions().map(
      (items) => items.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Future<SubscriptionRecord?> getSubscription(int id) async {
    final item = await _database.subscriptionDao.getSubscription(id);
    return item == null ? null : _toDomain(item);
  }

  @override
  Future<SubscriptionRecord> createSubscription(SubscriptionInput input) async {
    input.validate();
    final id = await _database.subscriptionDao.createSubscription(
      db.SubscriptionsCompanion.insert(
        categoryId: input.categoryId,
        channelId: Value(input.channelId),
        name: input.name.trim(),
        amount: input.amount,
        billingCycle: input.billingCycle.name,
        billingDay: input.nextBillingDate.day,
        startDate: _storeDate(input.startDate),
        endDate: Value(
          input.endDate == null ? null : _storeDate(input.endDate!),
        ),
        nextBillingDate: _storeDate(input.nextBillingDate),
        note: Value(_normalizedNote(input.note)),
        autoCreateTransaction: Value(input.autoCreateTransaction),
      ),
    );
    return _getRequired(id);
  }

  @override
  Future<SubscriptionRecord> updateSubscription(
    int id,
    SubscriptionInput input,
  ) async {
    input.validate();
    final updated = await _database.subscriptionDao.updateSubscriptionFields(
      id,
      db.SubscriptionsCompanion(
        categoryId: Value(input.categoryId),
        channelId: Value(input.channelId),
        name: Value(input.name.trim()),
        amount: Value(input.amount),
        billingCycle: Value(input.billingCycle.name),
        billingDay: Value(input.nextBillingDate.day),
        startDate: Value(_storeDate(input.startDate)),
        endDate: Value(
          input.endDate == null ? null : _storeDate(input.endDate!),
        ),
        nextBillingDate: Value(_storeDate(input.nextBillingDate)),
        note: Value(_normalizedNote(input.note)),
        autoCreateTransaction: Value(input.autoCreateTransaction),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    if (updated != 1) throw StateError('找不到訂閱 $id');
    return _getRequired(id);
  }

  @override
  Future<void> setSubscriptionActive(int id, bool active) async {
    if (await _database.subscriptionDao.setSubscriptionActive(id, active) !=
        1) {
      throw StateError('找不到訂閱 $id');
    }
  }

  @override
  Future<int> processDueSubscriptions(DateTime today) async {
    final todayOnly = DateTime(today.year, today.month, today.day);
    final endOfToday = taipeiDayRange(
      todayOnly,
    ).end.subtract(const Duration(microseconds: 1));
    var createdCount = 0;

    await _database.transaction(() async {
      final due = await _database.subscriptionDao.getDueSubscriptions(
        endOfToday,
      );
      for (final item in due) {
        var billingDate = _readDate(item.nextBillingDate);
        final endDate = item.endDate == null ? null : _readDate(item.endDate!);
        var active = item.isActive;

        while (!billingDate.isAfter(todayOnly)) {
          if (endDate != null && billingDate.isAfter(endDate)) {
            active = false;
            break;
          }
          await _database.transactionDao.createTransaction(
            db.TransactionsCompanion.insert(
              categoryId: item.categoryId,
              channelId: Value(item.channelId),
              type: TransactionType.expense.name,
              amount: item.amount,
              occurredAt: toUtcFromTaipei(
                DateTime(
                  billingDate.year,
                  billingDate.month,
                  billingDate.day,
                  12,
                ),
              ),
              note: Value('${item.name} 自動扣款'),
              source: Value(TransactionSource.subscription.name),
            ),
          );
          createdCount++;
          billingDate = nextBillingDate(
            billingDate,
            BillingCycle.values.byName(item.billingCycle),
            billingDay: item.billingDay,
          );
        }

        if (endDate != null && billingDate.isAfter(endDate)) active = false;
        await _database.subscriptionDao.updateSubscriptionFields(
          item.id,
          db.SubscriptionsCompanion(
            nextBillingDate: Value(_storeDate(billingDate)),
            isActive: Value(active),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
      }
    });
    return createdCount;
  }

  Future<SubscriptionRecord> _getRequired(int id) async {
    final item = await getSubscription(id);
    if (item == null) throw StateError('找不到訂閱 $id');
    return item;
  }

  SubscriptionRecord _toDomain(db.SubscriptionEntry item) => SubscriptionRecord(
    id: item.id,
    categoryId: item.categoryId,
    channelId: item.channelId,
    name: item.name,
    amount: item.amount,
    billingCycle: BillingCycle.values.byName(item.billingCycle),
    billingDay: item.billingDay,
    startDate: _readDate(item.startDate),
    endDate: item.endDate == null ? null : _readDate(item.endDate!),
    nextBillingDate: _readDate(item.nextBillingDate),
    note: item.note,
    isActive: item.isActive,
    autoCreateTransaction: item.autoCreateTransaction,
    createdAt: item.createdAt.toUtc(),
    updatedAt: item.updatedAt.toUtc(),
  );

  DateTime _storeDate(DateTime date) =>
      toUtcFromTaipei(DateTime(date.year, date.month, date.day));

  DateTime _readDate(DateTime date) {
    final local = toTaipeiTime(date);
    return DateTime(local.year, local.month, local.day);
  }

  String? _normalizedNote(String? note) {
    final value = note?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
