import '../../../core/utils/taipei_time.dart';
import '../../categories/domain/category.dart';
import '../../channels/domain/channel.dart';
import 'transaction.dart';

enum ChannelFilterMode { any, unset, selected }

class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.type,
    this.categoryId,
    this.channelMode = ChannelFilterMode.any,
    this.channelId,
    this.startDate,
    this.endDate,
  });

  final String query;
  final TransactionType? type;
  final int? categoryId;
  final ChannelFilterMode channelMode;
  final int? channelId;
  final DateTime? startDate;
  final DateTime? endDate;

  int get activeFilterCount => [
    type != null,
    categoryId != null,
    channelMode != ChannelFilterMode.any,
    startDate != null || endDate != null,
  ].where((active) => active).length;

  TransactionFilter withQuery(String value) => TransactionFilter(
    query: value,
    type: type,
    categoryId: categoryId,
    channelMode: channelMode,
    channelId: channelId,
    startDate: startDate,
    endDate: endDate,
  );
}

List<TransactionRecord> filterTransactions({
  required List<TransactionRecord> transactions,
  required List<Category> categories,
  required List<ShoppingChannel> channels,
  required TransactionFilter filter,
}) {
  final categoryNames = {for (final item in categories) item.id: item.name};
  final channelNames = {for (final item in channels) item.id: item.name};
  final query = filter.query.trim().toLowerCase();
  final start = filter.startDate == null
      ? null
      : DateTime(
          filter.startDate!.year,
          filter.startDate!.month,
          filter.startDate!.day,
        );
  final end = filter.endDate == null
      ? null
      : DateTime(
          filter.endDate!.year,
          filter.endDate!.month,
          filter.endDate!.day,
        );

  return transactions
      .where((transaction) {
        if (filter.type != null && transaction.type != filter.type) {
          return false;
        }
        if (filter.categoryId != null &&
            transaction.categoryId != filter.categoryId) {
          return false;
        }
        if (filter.channelMode == ChannelFilterMode.unset &&
            transaction.channelId != null) {
          return false;
        }
        if (filter.channelMode == ChannelFilterMode.selected &&
            transaction.channelId != filter.channelId) {
          return false;
        }

        final localDate = toTaipeiTime(transaction.occurredAt);
        final localDay = DateTime(
          localDate.year,
          localDate.month,
          localDate.day,
        );
        if (start != null && localDay.isBefore(start)) return false;
        if (end != null && localDay.isAfter(end)) return false;

        if (query.isEmpty) return true;
        final searchable = [
          transaction.note ?? '',
          categoryNames[transaction.categoryId] ?? '',
          if (transaction.channelId != null)
            channelNames[transaction.channelId] ?? '',
          transaction.amount.toString(),
          transaction.type == TransactionType.expense ? '支出' : '收入',
          transaction.source == TransactionSource.subscription ? '訂閱' : '手動',
        ].join(' ').toLowerCase();
        return searchable.contains(query);
      })
      .toList(growable: false);
}
