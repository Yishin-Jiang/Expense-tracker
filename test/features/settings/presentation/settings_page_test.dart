import 'dart:typed_data';

import 'package:accounting_app/app/app.dart';
import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/core/database/database_provider.dart';
import 'package:accounting_app/features/settings/domain/data_file_gateway.dart';
import 'package:accounting_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late _FakeFileGateway gateway;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = _FakeFileGateway();
  });

  tearDown(() => database.close());

  testWidgets('settings shows data actions and version', (tester) async {
    await _pumpSettings(tester, database, gateway);

    expect(find.text('設定'), findsOneWidget);
    expect(find.byKey(const Key('exportCsvButton')), findsOneWidget);
    expect(find.byKey(const Key('exportBackupButton')), findsOneWidget);
    expect(find.byKey(const Key('restoreBackupButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('exportCsvButton')));
    await tester.pumpAndSettle();
    expect(gateway.shared?.name, endsWith('.csv'));

    await tester.scrollUntilVisible(find.text('關於'), 300);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('appVersionText')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Future<void> _pumpSettings(
  WidgetTester tester,
  AppDatabase database,
  DataFileGateway gateway,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        dataFileGatewayProvider.overrideWithValue(gateway),
        appVersionProvider.overrideWith(
          (ref) async =>
              const AppVersionInfo(version: '1.0.0', buildNumber: '1'),
        ),
      ],
      child: const AccountingApp(initialLocation: '/settings'),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeFileGateway implements DataFileGateway {
  ExportedDataFile? shared;

  @override
  Future<Uint8List?> pickBackup() async => null;

  @override
  Future<void> share(ExportedDataFile file) async => shared = file;
}
