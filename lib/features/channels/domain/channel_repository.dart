import 'channel.dart';

abstract interface class ChannelRepository {
  Stream<List<ShoppingChannel>> watchActiveChannels();
}
