import 'dart:convert';

import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/features/settings/domain/data_file_gateway.dart';
import 'package:accounting_app/features/settings/domain/data_management_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late _FakeFileGateway gateway;
  late DataManagementService service;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = _FakeFileGateway();
    service = DataManagementService(database, gateway);
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() => database.close());

  test('complete backup restores related records', () async {
    final categories = await database.select(database.categories).get();
    final channels = await database.select(database.channels).get();
    await database
        .into(database.transactions)
        .insert(
          TransactionsCompanion.insert(
            categoryId: categories.first.id,
            channelId: Value(channels.first.id),
            type: 'expense',
            amount: 135,
            occurredAt: DateTime.utc(2026, 7, 22, 4, 30),
            note: const Value('午餐'),
          ),
        );
    await database
        .into(database.subscriptions)
        .insert(
          SubscriptionsCompanion.insert(
            categoryId: categories.first.id,
            name: 'Spotify',
            amount: 149,
            billingCycle: 'monthly',
            billingDay: 10,
            startDate: DateTime.utc(2026, 1, 10),
            nextBillingDate: DateTime.utc(2026, 8, 10),
          ),
        );

    final backup = await service.buildBackup();
    await service.clearAllData();
    final restored = await service.restoreBackup(backup.bytes);

    expect(restored.transactionCount, 1);
    expect(restored.subscriptionCount, 1);
    expect(await database.select(database.transactions).get(), hasLength(1));
    expect(
      (await database.select(database.subscriptions).get()).single.name,
      'Spotify',
    );
  });

  test('invalid backup is rejected before current data changes', () async {
    final before = await service.loadSummary();

    expect(
      () => service.restoreBackup(Uint8List.fromList(utf8.encode('{}'))),
      throwsA(isA<BackupFormatException>()),
    );

    final after = await service.loadSummary();
    expect(after.categoryCount, before.categoryCount);
  });

  test(
    'broken relationships are rejected without replacing current data',
    () async {
      final categories = await database.select(database.categories).get();
      await database
          .into(database.transactions)
          .insert(
            TransactionsCompanion.insert(
              categoryId: categories.first.id,
              type: 'expense',
              amount: 60,
              occurredAt: DateTime.utc(2026, 7, 22),
            ),
          );
      final backup = await service.buildBackup();
      final document =
          jsonDecode(utf8.decode(backup.bytes)) as Map<String, dynamic>;
      final data = document['data'] as Map<String, dynamic>;
      final transactions = data['transactions'] as List<dynamic>;
      (transactions.first as Map<String, dynamic>)['categoryId'] = 999999;
      final broken = Uint8List.fromList(utf8.encode(jsonEncode(document)));

      expect(
        () => service.restoreBackup(broken),
        throwsA(isA<BackupFormatException>()),
      );
      expect(await database.select(database.transactions).get(), hasLength(1));
    },
  );

  test('CSV includes UTF-8 BOM and escapes note contents', () async {
    final categories = await database.select(database.categories).get();
    await database
        .into(database.transactions)
        .insert(
          TransactionsCompanion.insert(
            categoryId: categories.first.id,
            type: 'expense',
            amount: 80,
            occurredAt: DateTime.utc(2026, 7, 22),
            note: const Value('咖啡, "大杯"'),
          ),
        );

    final file = await service.buildTransactionsCsv();
    expect(file.bytes.take(3), [0xEF, 0xBB, 0xBF]);
    final csv = utf8.decode(file.bytes.skip(3).toList());
    expect(csv, contains('"咖啡, ""大杯"""'));
    expect(csv, contains('"80"'));
  });

  test('clear removes user data and restores defaults', () async {
    final categories = await database.select(database.categories).get();
    await database
        .into(database.transactions)
        .insert(
          TransactionsCompanion.insert(
            categoryId: categories.first.id,
            type: 'expense',
            amount: 50,
            occurredAt: DateTime.utc(2026, 7, 22),
          ),
        );

    await service.clearAllData();
    final summary = await service.loadSummary();

    expect(summary.transactionCount, 0);
    expect(summary.subscriptionCount, 0);
    expect(summary.categoryCount, greaterThan(0));
  });
}

class _FakeFileGateway implements DataFileGateway {
  Uint8List? picked;
  ExportedDataFile? shared;

  @override
  Future<Uint8List?> pickBackup() async => picked;

  @override
  Future<void> share(ExportedDataFile file) async => shared = file;
}
