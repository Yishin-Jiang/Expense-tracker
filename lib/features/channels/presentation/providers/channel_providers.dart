import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../data/drift_channel_repository.dart';
import '../../domain/channel.dart';
import '../../domain/channel_repository.dart';

final channelRepositoryProvider = Provider<ChannelRepository>(
  (ref) => DriftChannelRepository(ref.watch(databaseProvider)),
);

final activeChannelsProvider =
    StreamProvider.autoDispose<List<ShoppingChannel>>(
      (ref) => ref.watch(channelRepositoryProvider).watchActiveChannels(),
    );

final channelByIdProvider = FutureProvider.autoDispose
    .family<ShoppingChannel?, int>(
      (ref, id) => ref.watch(channelRepositoryProvider).getChannel(id),
    );
