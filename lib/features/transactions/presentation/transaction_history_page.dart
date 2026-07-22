import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/taipei_time.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../channels/domain/channel.dart';
import '../../channels/presentation/providers/channel_providers.dart';
import '../domain/transaction.dart';
import '../domain/transaction_filter.dart';
import 'providers/transaction_providers.dart';

class TransactionHistoryPage extends ConsumerStatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  ConsumerState<TransactionHistoryPage> createState() =>
      _TransactionHistoryPageState();
}

class _TransactionHistoryPageState
    extends ConsumerState<TransactionHistoryPage> {
  final _searchController = TextEditingController();
  TransactionFilter _filter = const TransactionFilter();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(allTransactionsProvider);
    final categories = ref.watch(allCategoriesProvider);
    final channels = ref.watch(activeChannelsProvider);
    final categoryItems = categories.asData?.value ?? const <Category>[];
    final channelItems = channels.asData?.value ?? const <ShoppingChannel>[];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '返回首頁',
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '交易紀錄',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/transactions/new'),
                icon: const Icon(Icons.add),
                label: const Text('記一筆'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('transactionSearchField'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '搜尋備註、類別、金額或訂閱',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除搜尋',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _filter = _filter.withQuery('');
                              });
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (value) {
                    setState(() => _filter = _filter.withQuery(value));
                  },
                ),
              ),
              const SizedBox(width: 10),
              Badge(
                isLabelVisible: _filter.activeFilterCount > 0,
                label: Text('${_filter.activeFilterCount}'),
                child: IconButton.filledTonal(
                  key: const Key('transactionFilterButton'),
                  tooltip: '篩選交易',
                  onPressed: () => _openFilters(categoryItems, channelItems),
                  icon: const Icon(Icons.tune),
                ),
              ),
            ],
          ),
          if (_filter.activeFilterCount > 0) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('clearTransactionFiltersButton'),
                onPressed: () => setState(() {
                  _filter = TransactionFilter(query: _searchController.text);
                }),
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('清除篩選條件'),
              ),
            ),
          ],
          const SizedBox(height: 18),
          transactions.when(
            data: (items) {
              final results = filterTransactions(
                transactions: items,
                categories: categoryItems,
                channels: channelItems,
                filter: _filter,
              );
              return _HistoryResults(
                transactions: results,
                categories: categoryItems,
                channels: channelItems,
              );
            },
            loading: () => const AppLoadingView(message: '正在載入交易'),
            error: (error, _) => AppErrorView(
              message: '交易載入失敗：$error',
              onRetry: () => ref.invalidate(allTransactionsProvider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters(
    List<Category> categories,
    List<ShoppingChannel> channels,
  ) async {
    final selected = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TransactionFilterSheet(
        initial: _filter,
        categories: categories,
        channels: channels,
      ),
    );
    if (selected != null && mounted) setState(() => _filter = selected);
  }
}

class _HistoryResults extends StatelessWidget {
  const _HistoryResults({
    required this.transactions,
    required this.categories,
    required this.channels,
  });
  final List<TransactionRecord> transactions;
  final List<Category> categories;
  final List<ShoppingChannel> channels;

  @override
  Widget build(BuildContext context) {
    var income = 0;
    var expense = 0;
    for (final item in transactions) {
      if (item.type == TransactionType.income) {
        income += item.amount;
      } else {
        expense += item.amount;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const Key('transactionSearchSummary'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ResultSummary(
                  label: '共 ${transactions.length} 筆',
                  value: '搜尋結果',
                ),
              ),
              Expanded(
                child: _ResultSummary(label: '支出', value: formatTwd(expense)),
              ),
              Expanded(
                child: _ResultSummary(label: '收入', value: formatTwd(income)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (transactions.isEmpty)
          const AppEmptyView(title: '找不到符合的交易', message: '試著調整關鍵字、日期或篩選條件。')
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < transactions.length; index++) ...[
                  _HistoryTile(
                    transaction: transactions[index],
                    category: _categoryById(
                      categories,
                      transactions[index].categoryId,
                    ),
                    channel: _channelById(
                      channels,
                      transactions[index].channelId,
                    ),
                  ),
                  if (index < transactions.length - 1)
                    const Divider(height: 1, indent: 64),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFFD9F0E0), fontSize: 11),
      ),
      const SizedBox(height: 5),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.transaction,
    required this.category,
    required this.channel,
  });
  final TransactionRecord transaction;
  final Category? category;
  final ShoppingChannel? channel;

  @override
  Widget build(BuildContext context) {
    final expense = transaction.type == TransactionType.expense;
    final date = toTaipeiTime(transaction.occurredAt);
    final note = transaction.note;
    final details = [
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
      ?channel?.name,
      if (note != null && note.isNotEmpty) note,
      if (transaction.source == TransactionSource.subscription) '訂閱自動記帳',
    ].join('・');
    return ListTile(
      key: Key('historyTransaction-${transaction.id}'),
      leading: CircleAvatar(
        backgroundColor: categoryColor(category?.color),
        foregroundColor: AppColors.ink,
        child: Icon(categoryIcon(category?.icon)),
      ),
      title: Text(category?.name ?? '未分類'),
      subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '${expense ? '−' : '+'} ${formatTwd(transaction.amount)}',
        style: TextStyle(
          color: expense ? AppColors.expense : AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: () => context.go('/transactions/${transaction.id}'),
    );
  }
}

class _TransactionFilterSheet extends StatefulWidget {
  const _TransactionFilterSheet({
    required this.initial,
    required this.categories,
    required this.channels,
  });
  final TransactionFilter initial;
  final List<Category> categories;
  final List<ShoppingChannel> channels;

  @override
  State<_TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<_TransactionFilterSheet> {
  TransactionType? _type;
  int? _categoryId;
  late ChannelFilterMode _channelMode;
  int? _channelId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _type = widget.initial.type;
    _categoryId = widget.initial.categoryId;
    _channelMode = widget.initial.channelMode;
    _channelId = widget.initial.channelId;
    _startDate = widget.initial.startDate;
    _endDate = widget.initial.endDate;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '篩選交易',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  key: const Key('resetFilterSheetButton'),
                  onPressed: () => setState(() {
                    _type = null;
                    _categoryId = null;
                    _channelMode = ChannelFilterMode.any;
                    _channelId = null;
                    _startDate = null;
                    _endDate = null;
                  }),
                  child: const Text('全部重設'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('filterTransactionType'),
              initialValue: _type?.name ?? 'all',
              decoration: const InputDecoration(labelText: '收支類型'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('全部')),
                DropdownMenuItem(value: 'expense', child: Text('支出')),
                DropdownMenuItem(value: 'income', child: Text('收入')),
              ],
              onChanged: (value) => setState(() {
                _type = value == null || value == 'all'
                    ? null
                    : TransactionType.values.byName(value);
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              key: const Key('filterCategory'),
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: '類別'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('全部類別')),
                for (final item in widget.categories)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('filterChannel'),
              initialValue: switch (_channelMode) {
                ChannelFilterMode.any => 'any',
                ChannelFilterMode.unset => 'unset',
                ChannelFilterMode.selected => 'selected:${_channelId ?? ''}',
              },
              decoration: const InputDecoration(labelText: '購物類型'),
              items: [
                const DropdownMenuItem(value: 'any', child: Text('全部購物類型')),
                const DropdownMenuItem(value: 'unset', child: Text('未設定')),
                for (final item in widget.channels)
                  DropdownMenuItem(
                    value: 'selected:${item.id}',
                    child: Text(item.name),
                  ),
              ],
              onChanged: (value) => setState(() {
                if (value == 'unset') {
                  _channelMode = ChannelFilterMode.unset;
                  _channelId = null;
                } else if (value?.startsWith('selected:') ?? false) {
                  _channelMode = ChannelFilterMode.selected;
                  _channelId = int.tryParse(value!.split(':').last);
                } else {
                  _channelMode = ChannelFilterMode.any;
                  _channelId = null;
                }
              }),
            ),
            const SizedBox(height: 16),
            Text('日期區間', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _FilterDateButton(
                    buttonKey: const Key('filterStartDate'),
                    label: '開始',
                    date: _startDate,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FilterDateButton(
                    buttonKey: const Key('filterEndDate'),
                    label: '結束',
                    date: _endDate,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const Key('applyTransactionFiltersButton'),
                onPressed: _dateRangeValid
                    ? () => Navigator.pop(
                        context,
                        TransactionFilter(
                          query: widget.initial.query,
                          type: _type,
                          categoryId: _categoryId,
                          channelMode: _channelMode,
                          channelId: _channelId,
                          startDate: _startDate,
                          endDate: _endDate,
                        ),
                      )
                    : null,
                child: Text(_dateRangeValid ? '套用篩選' : '結束日期需晚於開始日期'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _dateRangeValid =>
      _startDate == null ||
      _endDate == null ||
      !_endDate!.isBefore(_startDate!);

  Future<void> _pickDate(bool start) async {
    final initial = start
        ? _startDate ?? _endDate ?? DateTime.now()
        : _endDate ?? _startDate ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = selected;
      } else {
        _endDate = selected;
      }
    });
  }
}

class _FilterDateButton extends StatelessWidget {
  const _FilterDateButton({
    required this.buttonKey,
    required this.label,
    required this.date,
    required this.onTap,
  });
  final Key buttonKey;
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: buttonKey,
    onPressed: onTap,
    icon: const Icon(Icons.calendar_month_outlined),
    label: Text(
      date == null ? label : '${date!.year}/${date!.month}/${date!.day}',
    ),
  );
}

Category? _categoryById(List<Category> items, int id) =>
    items.where((item) => item.id == id).firstOrNull;

ShoppingChannel? _channelById(List<ShoppingChannel> items, int? id) =>
    id == null ? null : items.where((item) => item.id == id).firstOrNull;
