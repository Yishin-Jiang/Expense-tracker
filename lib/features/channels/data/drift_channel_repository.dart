import '../../../core/database/app_database.dart' as db;
import '../domain/channel.dart';
import '../domain/channel_repository.dart';

class DriftChannelRepository implements ChannelRepository {
  DriftChannelRepository(this._database);
  final db.AppDatabase _database;

  @override
  Future<ShoppingChannel?> getChannel(int id) async {
    final item = await (_database.select(
      _database.channels,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return item == null
        ? null
        : ShoppingChannel(
            id: item.id,
            code: item.code,
            name: item.name,
            isActive: item.isActive,
          );
  }

  @override
  Stream<List<ShoppingChannel>> watchActiveChannels() {
    return _database.channelDao.watchActiveChannels().map(
      (items) => items
          .map(
            (item) => ShoppingChannel(
              id: item.id,
              code: item.code,
              name: item.name,
              isActive: item.isActive,
            ),
          )
          .toList(growable: false),
    );
  }
}
