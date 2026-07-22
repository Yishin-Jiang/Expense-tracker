import 'package:accounting_app/app/app.dart';
import 'package:accounting_app/features/categories/domain/category.dart';
import 'package:accounting_app/features/categories/domain/category_repository.dart';
import 'package:accounting_app/features/categories/presentation/providers/category_providers.dart';
import 'package:accounting_app/features/channels/domain/channel.dart';
import 'package:accounting_app/features/channels/domain/channel_repository.dart';
import 'package:accounting_app/features/channels/presentation/providers/channel_providers.dart';
import 'package:accounting_app/features/transactions/domain/transaction.dart';
import 'package:accounting_app/features/transactions/domain/transaction_repository.dart';
import 'package:accounting_app/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:accounting_app/features/subscriptions/domain/subscription.dart';
import 'package:accounting_app/features/subscriptions/domain/subscription_repository.dart';
import 'package:accounting_app/features/subscriptions/presentation/providers/subscription_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app starts on the home page', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            RegExp(r'^\d{1,2} 月 \d{1,2} 日$').hasMatch(widget.data ?? ''),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('今天也要花得明白'), findsNothing);
    expect(find.text('還沒有記帳紀錄'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('bottom navigation opens calendar and transaction pages', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('月曆'));
    await tester.pump();
    expect(find.text('每天的花費，一眼就知道'), findsOneWidget);
    expect(find.text('還沒有記帳紀錄'), findsNothing);
    await tester.tap(find.text('記帳'));
    await tester.pump();
    expect(find.text('新增一筆'), findsOneWidget);
    expect(find.text('每天的花費，一眼就知道'), findsNothing);
  });

  testWidgets('quick entry prefills its expense category', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    final quickLunch = find.byKey(const Key('quickEntry-午餐'));
    await tester.scrollUntilVisible(quickLunch, 200);
    await tester.tap(quickLunch);
    await tester.pumpAndSettle();

    expect(find.text('新增一筆'), findsOneWidget);
    final dropdown = tester.widget<DropdownButtonFormField<int>>(
      find.byKey(const Key('category-expense')),
    );
    expect(dropdown.initialValue, 12);
  });
}

Widget _testApp() => ProviderScope(
  overrides: [
    categoryRepositoryProvider.overrideWithValue(
      const _FakeCategoryRepository(),
    ),
    channelRepositoryProvider.overrideWithValue(const _FakeChannelRepository()),
    transactionRepositoryProvider.overrideWithValue(
      const _FakeTransactionRepository(),
    ),
    subscriptionRepositoryProvider.overrideWithValue(
      const _FakeSubscriptionRepository(),
    ),
  ],
  child: const AccountingApp(),
);

class _FakeCategoryRepository implements CategoryRepository {
  const _FakeCategoryRepository();

  @override
  Stream<List<Category>> watchAllCategories() => Stream.value(const []);

  @override
  Stream<List<Category>> watchActiveCategories(CategoryType type) {
    if (type == CategoryType.income) return Stream.value(const []);
    return Stream.value([
      Category(
        id: 12,
        name: '午餐',
        type: CategoryType.expense,
        sortOrder: 12,
        isActive: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);
  }

  @override
  Future<Category?> getCategory(int id) async => null;

  @override
  Future<Category> createCategory(CategoryInput input) {
    throw UnimplementedError();
  }

  @override
  Future<Category> updateCategory(int id, CategoryInput input) {
    throw UnimplementedError();
  }

  @override
  Future<void> archiveCategory(int id) {
    throw UnimplementedError();
  }

  @override
  Future<void> restoreCategory(int id) {
    throw UnimplementedError();
  }
}

class _FakeChannelRepository implements ChannelRepository {
  const _FakeChannelRepository();

  @override
  Stream<List<ShoppingChannel>> watchActiveChannels() {
    return Stream.value(const []);
  }

  @override
  Future<ShoppingChannel?> getChannel(int id) async => null;
}

class _FakeTransactionRepository implements TransactionRepository {
  const _FakeTransactionRepository();

  @override
  Stream<List<TransactionRecord>> watchAllTransactions() =>
      Stream.value(const []);

  @override
  Stream<List<TransactionRecord>> watchTransactions(
    TransactionDateRange range,
  ) => Stream.value(const []);

  @override
  Stream<DailyTransactionSummary> watchDailySummary(DateTime date) =>
      Stream.value(
        DailyTransactionSummary(
          date: date,
          income: 0,
          expense: 0,
          transactionCount: 0,
        ),
      );

  @override
  Future<TransactionRecord?> getTransaction(int id) async => null;

  @override
  Future<TransactionRecord> createTransaction(TransactionInput input) =>
      throw UnimplementedError();

  @override
  Future<TransactionRecord> updateTransaction(int id, TransactionInput input) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTransaction(int id) => throw UnimplementedError();
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  const _FakeSubscriptionRepository();

  @override
  Stream<List<SubscriptionRecord>> watchSubscriptions() =>
      Stream.value(const []);

  @override
  Future<SubscriptionRecord?> getSubscription(int id) async => null;

  @override
  Future<SubscriptionRecord> createSubscription(SubscriptionInput input) =>
      throw UnimplementedError();

  @override
  Future<SubscriptionRecord> updateSubscription(
    int id,
    SubscriptionInput input,
  ) => throw UnimplementedError();

  @override
  Future<void> setSubscriptionActive(int id, bool active) async {}

  @override
  Future<int> processDueSubscriptions(DateTime today) async => 0;
}
