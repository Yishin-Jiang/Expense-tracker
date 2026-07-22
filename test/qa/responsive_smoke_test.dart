import 'package:accounting_app/app/app.dart';
import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/core/database/database_provider.dart';
import 'package:accounting_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profiles = [
    _DeviceProfile('compact portrait', Size(320, 640), 1),
    _DeviceProfile('iPhone portrait', Size(390, 844), 1),
    _DeviceProfile('large iPhone portrait', Size(430, 932), 1),
    _DeviceProfile('iPhone large text', Size(390, 844), 1.5),
    _DeviceProfile('iPhone landscape', Size(844, 390), 1),
  ];

  for (final profile in profiles) {
    testWidgets('primary pages fit ${profile.name}', (tester) async {
      tester.view.physicalSize = profile.size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = profile.textScale;
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
          reason:
              '$route should render on ${profile.size.width.toInt()} × '
              '${profile.size.height.toInt()} at ${profile.textScale}× text',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}

class _DeviceProfile {
  const _DeviceProfile(this.name, this.size, this.textScale);

  final String name;
  final Size size;
  final double textScale;
}
