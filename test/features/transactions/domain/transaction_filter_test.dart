import 'package:accounting_app/core/utils/taipei_time.dart';
import 'package:accounting_app/features/categories/domain/category.dart';
import 'package:accounting_app/features/channels/domain/channel.dart';
import 'package:accounting_app/features/transactions/domain/transaction.dart';
import 'package:accounting_app/features/transactions/domain/transaction_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final categories = [
    Category(
      id: 1,
      parentId: 3,
      name: '午餐',
      type: CategoryType.expense,
      sortOrder: 1,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    Category(
      id: 2,
      name: '薪資',
      type: CategoryType.income,
      sortOrder: 2,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    Category(
      id: 3,
      name: '飲食',
      type: CategoryType.expense,
      sortOrder: 0,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
  const channels = [
    ShoppingChannel(id: 1, code: 'online', name: '網購', isActive: true),
  ];
  final transactions = [
    _transaction(
      id: 1,
      categoryId: 1,
      channelId: 1,
      type: TransactionType.expense,
      amount: 120,
      date: DateTime(2026, 7, 10, 12),
      note: '學校午餐',
    ),
    _transaction(
      id: 2,
      categoryId: 2,
      type: TransactionType.income,
      amount: 3000,
      date: DateTime(2026, 7, 22, 9),
      note: '打工收入',
    ),
  ];

  test('search matches note, category, channel, amount, and type', () {
    for (final query in ['學校', '午餐', '飲食', '網購', '120', '支出']) {
      final result = filterTransactions(
        transactions: transactions,
        categories: categories,
        channels: channels,
        filter: TransactionFilter(query: query),
      );
      expect(result.map((item) => item.id), [1], reason: query);
    }
  });

  test('selecting a parent category includes child transactions', () {
    final result = filterTransactions(
      transactions: transactions,
      categories: categories,
      channels: channels,
      filter: const TransactionFilter(categoryId: 3),
    );
    expect(result.map((item) => item.id), [1]);
  });

  test('combines type category channel and inclusive date filters', () {
    final result = filterTransactions(
      transactions: transactions,
      categories: categories,
      channels: channels,
      filter: TransactionFilter(
        type: TransactionType.expense,
        categoryId: 1,
        channelMode: ChannelFilterMode.selected,
        channelId: 1,
        startDate: DateTime(2026, 7, 10),
        endDate: DateTime(2026, 7, 10),
      ),
    );
    expect(result.map((item) => item.id), [1]);
  });

  test('can filter transactions without a shopping channel', () {
    final result = filterTransactions(
      transactions: transactions,
      categories: categories,
      channels: channels,
      filter: const TransactionFilter(channelMode: ChannelFilterMode.unset),
    );
    expect(result.map((item) => item.id), [2]);
  });
}

TransactionRecord _transaction({
  required int id,
  required int categoryId,
  required TransactionType type,
  required int amount,
  required DateTime date,
  int? channelId,
  String? note,
}) => TransactionRecord(
  id: id,
  categoryId: categoryId,
  channelId: channelId,
  type: type,
  amount: amount,
  occurredAt: toUtcFromTaipei(date),
  note: note,
  source: TransactionSource.manual,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
