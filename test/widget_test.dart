import 'package:accounting_app/app/app.dart';
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
    await tester.pumpWidget(const ProviderScope(child: AccountingApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月曆'));
    await tester.pumpAndSettle();
    expect(find.text('每天的花費，一眼就知道'), findsOneWidget);
    await tester.tap(find.text('記帳'));
    await tester.pumpAndSettle();
    expect(find.text('新增一筆'), findsOneWidget);
  });
}
