import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/features/channels/data/drift_channel_repository.dart';
import 'package:accounting_app/features/channels/domain/channel.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftChannelRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftChannelRepository(database);
  });

  tearDown(() => database.close());

  test('creates, renames, archives, and restores a shopping channel', () async {
    final created = await repository.createChannel(
      const ShoppingChannelInput(name: ' 外送平台 '),
    );
    expect(created.name, '外送平台');
    expect(created.isActive, isTrue);

    final updated = await repository.updateChannel(
      created.id,
      const ShoppingChannelInput(name: '校園外送'),
    );
    expect(updated.name, '校園外送');

    await repository.setChannelActive(created.id, false);
    expect(
      await repository.watchActiveChannels().first,
      isNot(
        contains(predicate<ShoppingChannel>((item) => item.id == created.id)),
      ),
    );
    expect(
      (await repository.watchAllChannels().first)
          .singleWhere((item) => item.id == created.id)
          .name,
      '校園外送',
    );

    await repository.setChannelActive(created.id, true);
    expect(
      await repository.watchActiveChannels().first,
      contains(predicate<ShoppingChannel>((item) => item.id == created.id)),
    );
  });

  test('rejects blank and duplicate channel names', () async {
    expect(
      () => repository.createChannel(const ShoppingChannelInput(name: '  ')),
      throwsA(isA<FormatException>()),
    );

    await repository.createChannel(const ShoppingChannelInput(name: '外送平台'));
    expect(
      () =>
          repository.createChannel(const ShoppingChannelInput(name: ' 外送平台 ')),
      throwsA(isA<FormatException>()),
    );
  });
}
