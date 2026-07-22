import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../domain/channel.dart';
import '../domain/channel_repository.dart';

class DriftChannelRepository implements ChannelRepository {
  DriftChannelRepository(this._database);
  final db.AppDatabase _database;

  @override
  Stream<List<ShoppingChannel>> watchAllChannels() {
    return _database.channelDao.watchAllChannels().map(
      (items) => items.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Future<ShoppingChannel?> getChannel(int id) async {
    final item = await (_database.select(
      _database.channels,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return item == null ? null : _toDomain(item);
  }

  @override
  Stream<List<ShoppingChannel>> watchActiveChannels() {
    return _database.channelDao.watchActiveChannels().map(
      (items) => items.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Future<ShoppingChannel> createChannel(ShoppingChannelInput input) async {
    input.validate();
    await _ensureUniqueName(input.name);
    final id = await _database.channelDao.createChannel(
      db.ChannelsCompanion.insert(
        code: 'custom_${DateTime.now().microsecondsSinceEpoch}',
        name: input.name.trim(),
      ),
    );
    return _getRequired(id);
  }

  @override
  Future<ShoppingChannel> updateChannel(
    int id,
    ShoppingChannelInput input,
  ) async {
    input.validate();
    await _ensureUniqueName(input.name, channelId: id);
    if (await _database.channelDao.updateChannelFields(
          id,
          db.ChannelsCompanion(name: Value(input.name.trim())),
        ) !=
        1) {
      throw StateError('找不到購物管道 $id');
    }
    return _getRequired(id);
  }

  @override
  Future<void> setChannelActive(int id, bool active) async {
    if (await _database.channelDao.updateChannelFields(
          id,
          db.ChannelsCompanion(isActive: Value(active)),
        ) !=
        1) {
      throw StateError('找不到購物管道 $id');
    }
  }

  Future<void> _ensureUniqueName(String name, {int? channelId}) async {
    final normalized = name.trim().toLowerCase();
    final items = await (_database.select(
      _database.channels,
    )..where((row) => row.name.lower().equals(normalized))).get();
    if (items.any((item) => item.id != channelId)) {
      throw const FormatException('已有相同名稱的購物管道');
    }
  }

  Future<ShoppingChannel> _getRequired(int id) async {
    final item = await (_database.select(
      _database.channels,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (item == null) throw StateError('找不到購物管道 $id');
    return _toDomain(item);
  }

  ShoppingChannel _toDomain(db.ChannelEntry item) => ShoppingChannel(
    id: item.id,
    code: item.code,
    name: item.name,
    isActive: item.isActive,
  );
}
