import 'package:accounting_app/app/app.dart';
import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/core/database/database_provider.dart';
import 'package:accounting_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('primary pages fit a compact phone without layout errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const routes = [
      '/home',
      '/calendar',
      '/transactions/new',
      '/transactions/history',
      '/analysis',
      '/subscriptions',
      '/categories',
      '/settings',
    ];

    for (final route in routes) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            appVersionProvider.overrideWith(
              (ref) async =>
                  const AppVersionInfo(version: '1.0.0', buildNumber: '1'),
            ),
          ],
          child: AccountingApp(initialLocation: route),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '$route should render on a 320 × 640 screen',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
