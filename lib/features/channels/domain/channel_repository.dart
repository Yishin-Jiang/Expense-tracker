import 'channel.dart';

abstract interface class ChannelRepository {
  Stream<List<ShoppingChannel>> watchAllChannels();
  Stream<List<ShoppingChannel>> watchActiveChannels();
  Future<ShoppingChannel?> getChannel(int id);
  Future<ShoppingChannel> createChannel(ShoppingChannelInput input);
  Future<ShoppingChannel> updateChannel(int id, ShoppingChannelInput input);
  Future<void> setChannelActive(int id, bool active);
}
