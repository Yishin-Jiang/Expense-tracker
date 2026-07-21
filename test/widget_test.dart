import 'package:accounting_app/app/app.dart';
import 'package:accounting_app/features/categories/domain/category.dart';
import 'package:accounting_app/features/categories/domain/category_repository.dart';
import 'package:accounting_app/features/categories/presentation/providers/category_providers.dart';
import 'package:accounting_app/features/channels/domain/channel.dart';
import 'package:accounting_app/features/channels/domain/channel_repository.dart';
import 'package:accounting_app/features/channels/presentation/providers/channel_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app starts on the home page', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AccountingApp()));
    await tester.pumpAndSettle();
    expect(find.text('今天也要花得明白'), findsOneWidget);
    expect(find.text('還沒有記帳紀錄'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('bottom navigation opens calendar and transaction pages', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          channelRepositoryProvider.overrideWithValue(
            const _FakeChannelRepository(),
          ),
        ],
        child: const AccountingApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('月曆'));
    await tester.pumpAndSettle();
    expect(find.text('每天的花費，一眼就知道'), findsOneWidget);
    await tester.tap(find.text('記帳'));
    await tester.pumpAndSettle();
    expect(find.text('新增一筆'), findsOneWidget);
  });
}

class _FakeCategoryRepository implements CategoryRepository {
  const _FakeCategoryRepository();

  @override
  Stream<List<Category>> watchActiveCategories(CategoryType type) {
    return Stream.value(const []);
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
