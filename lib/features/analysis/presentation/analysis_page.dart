import 'dart:math' as math;

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
import '../../transactions/domain/transaction.dart';
import '../domain/analysis_month_snapshot.dart';
import 'providers/analysis_providers.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final today = ref.read(analysisTodayProvider);
    _month = DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final analysis = ref.watch(analysisMonthProvider(_month));
    final categories = ref.watch(allCategoriesProvider);
    final channels = ref.watch(allChannelsProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        children: [
          Text('分析', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('看懂錢花去哪裡，再決定下一步', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          _MonthSelector(
            month: _month,
            onPrevious: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
          ),
          const SizedBox(height: 18),
          analysis.when(
            data: (snapshot) {
              final categoryItems = categories.asData?.value ?? const [];
              final channelItems = channels.asData?.value ?? const [];
              return Column(
                children: [
                  _SummaryCards(snapshot: snapshot),
                  const SizedBox(height: 16),
                  _ComparisonCard(snapshot: snapshot),
                  const SizedBox(height: 24),
                  _SectionCard(
                    title: '每日支出趨勢',
                    subtitle: '長條越高，代表當日支出越多',
                    child: _DailyExpenseChart(snapshot: snapshot),
                  ),
                  const SizedBox(height: 16),
                  _CategoryAnalysis(
                    snapshot: snapshot,
                    categories: categoryItems,
                    onCategoryTap: (categoryId) => _showCategoryTransactions(
                      snapshot,
                      categoryId,
                      categoryItems,
                      channelItems,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ChannelAnalysis(snapshot: snapshot, channels: channelItems),
                ],
              );
            },
            loading: () => const AppLoadingView(message: '正在整理本月分析'),
            error: (error, _) => AppErrorView(
              message: '分析載入失敗：$error',
              onRetry: () => ref.invalidate(analysisMonthProvider(_month)),
            ),
          ),
        ],
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() => _month = DateTime(_month.year, _month.month + offset));
  }

  void _showCategoryTransactions(
    AnalysisMonthSnapshot snapshot,
    int categoryId,
    List<Category> categories,
    List<ShoppingChannel> channels,
  ) {
    final category = _categoryById(categories, categoryId);
    final transactions = snapshot.transactionsForCategory(categoryId);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text(
              '${category?.name ?? '未分類'}交易',
              key: const Key('analysisTransactionSheetTitle'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '${snapshot.month.year} 年 ${snapshot.month.month} 月・${transactions.length} 筆',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            for (final transaction in transactions)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  key: Key('analysisTransaction-${transaction.id}'),
                  leading: CircleAvatar(
                    backgroundColor: categoryColor(category?.color),
                    foregroundColor: AppColors.ink,
                    child: Icon(categoryIcon(category?.icon)),
                  ),
                  title: Text(transaction.note ?? category?.name ?? '未分類'),
                  subtitle: Text(_transactionDetails(transaction, channels)),
                  trailing: Text(
                    '− ${formatTwd(transaction.amount)}',
                    style: const TextStyle(
                      color: AppColors.expense,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.go('/transactions/${transaction.id}');
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _transactionDetails(
    TransactionRecord transaction,
    List<ShoppingChannel> channels,
  ) {
    final date = toTaipeiTime(transaction.occurredAt);
    final channel = transaction.channelId == null
        ? null
        : channels
              .where((item) => item.id == transaction.channelId)
              .firstOrNull;
    return '${date.month}/${date.day}・${channel?.name ?? '未設定購物管道'}';
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Card(
    child: Row(
      children: [
        IconButton(
          key: const Key('analysisPreviousMonthButton'),
          tooltip: '上個月',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            '${month.year} 年 ${month.month} 月',
            key: const Key('analysisMonthTitle'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          key: const Key('analysisNextMonthButton'),
          tooltip: '下個月',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.snapshot});
  final AnalysisMonthSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _SummaryCard(
          label: '收入',
          value: formatTwd(snapshot.income),
          color: AppColors.primary,
          valueKey: const Key('analysisIncome'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _SummaryCard(
          label: '支出',
          value: formatTwd(snapshot.expense),
          color: AppColors.expense,
          valueKey: const Key('analysisExpense'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _SummaryCard(
          label: '結餘',
          value: formatTwd(snapshot.balance),
          color: snapshot.balance < 0 ? AppColors.expense : AppColors.primary,
          valueKey: const Key('analysisBalance'),
        ),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.valueKey,
  });
  final String label;
  final String value;
  final Color color;
  final Key valueKey;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              key: valueKey,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.snapshot});
  final AnalysisMonthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final change = snapshot.expenseChangePercent;
    final decreased = change != null && change < 0;
    final unchanged = change != null && change.abs() < 0.05;
    final message = change == null
        ? (snapshot.expense == 0 ? '本月與上月都還沒有支出' : '上月沒有支出，從本月開始建立比較基準')
        : unchanged
        ? '本月支出與上月持平'
        : '本月支出較上月${decreased ? '減少' : '增加'} ${change.abs().toStringAsFixed(1)}%';
    final neutral = unchanged || (change == null && snapshot.expense == 0);
    return Container(
      key: const Key('analysisComparison'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: neutral
            ? AppColors.warning.withValues(alpha: 0.45)
            : decreased
            ? AppColors.primaryContainer
            : AppColors.expenseContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            neutral
                ? Icons.trending_flat
                : decreased
                ? Icons.trending_down
                : Icons.trending_up,
            color: neutral
                ? AppColors.ink
                : decreased
                ? AppColors.primary
                : AppColors.expense,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  '上月支出 ${formatTwd(snapshot.previousExpense)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
          child,
        ],
      ),
    ),
  );
}

class _DailyExpenseChart extends StatelessWidget {
  const _DailyExpenseChart({required this.snapshot});
  final AnalysisMonthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final days = DateTime(snapshot.month.year, snapshot.month.month + 1, 0).day;
    final maxExpense = snapshot.dailyExpenses.values.fold<int>(0, math.max);
    if (maxExpense == 0) {
      return const SizedBox(
        height: 90,
        child: Center(child: Text('本月還沒有支出資料')),
      );
    }

    return SizedBox(
      height: 150,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var day = 1; day <= days; day++)
              _DailyBar(
                day: day,
                amount: snapshot.dailyExpenses[day] ?? 0,
                maxAmount: maxExpense,
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyBar extends StatelessWidget {
  const _DailyBar({
    required this.day,
    required this.amount,
    required this.maxAmount,
  });
  final int day;
  final int amount;
  final int maxAmount;

  @override
  Widget build(BuildContext context) {
    final height = amount == 0 ? 2.0 : math.max(8.0, amount / maxAmount * 108);
    return Semantics(
      label: '$day 日支出 ${formatTwd(amount)}',
      child: SizedBox(
        width: 28,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Tooltip(
              message: '$day 日 ${formatTwd(amount)}',
              child: Container(
                key: Key('analysisDayBar-$day'),
                width: 14,
                height: height,
                decoration: BoxDecoration(
                  color: amount == 0 ? AppColors.divider : AppColors.expense,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text('$day', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CategoryAnalysis extends StatelessWidget {
  const _CategoryAnalysis({
    required this.snapshot,
    required this.categories,
    required this.onCategoryTap,
  });
  final AnalysisMonthSnapshot snapshot;
  final List<Category> categories;
  final ValueChanged<int> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final entries = snapshot.categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return const _SectionCard(
        title: '支出類別',
        subtitle: '開始記帳後，這裡會顯示類別占比',
        child: SizedBox(height: 90, child: Center(child: Text('本月還沒有支出資料'))),
      );
    }

    final colors = [
      for (final entry in entries)
        categoryColor(_categoryById(categories, entry.key)?.color),
    ];
    return _SectionCard(
      title: '支出類別',
      subtitle: '點擊類別可查看本月交易',
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(140),
                  painter: _DonutChartPainter(
                    values: entries.map((entry) => entry.value).toList(),
                    colors: colors,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('總支出', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 3),
                    Text(
                      formatTwd(snapshot.expense),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < entries.length; index++)
            _CategoryRow(
              category: _categoryById(categories, entries[index].key),
              categoryId: entries[index].key,
              amount: entries[index].value,
              total: snapshot.expense,
              color: colors[index],
              onTap: () => onCategoryTap(entries[index].key),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.categoryId,
    required this.amount,
    required this.total,
    required this.color,
    required this.onTap,
  });
  final Category? category;
  final int categoryId;
  final int amount;
  final int total;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : amount / total * 100;
    return ListTile(
      key: Key('analysisCategory-$categoryId'),
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color,
        foregroundColor: AppColors.ink,
        child: Icon(categoryIcon(category?.icon)),
      ),
      title: Text(category?.name ?? '未分類'),
      subtitle: Text('${percent.toStringAsFixed(1)}%'),
      trailing: Text(
        formatTwd(amount),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      onTap: onTap,
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({required this.values, required this.colors});
  final List<int> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) return;
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.butt;
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index] / total * math.pi * 2;
      paint.color = colors[index];
      canvas.drawArc(rect.deflate(12), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

class _ChannelAnalysis extends StatelessWidget {
  const _ChannelAnalysis({required this.snapshot, required this.channels});
  final AnalysisMonthSnapshot snapshot;
  final List<ShoppingChannel> channels;

  @override
  Widget build(BuildContext context) {
    final entries = snapshot.channelExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _SectionCard(
      title: '購物管道',
      subtitle: '各購物管道支出比例',
      child: entries.isEmpty
          ? const SizedBox(
              height: 90,
              child: Center(child: Text('本月還沒有購物管道資料')),
            )
          : Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      for (var index = 0; index < entries.length; index++)
                        Expanded(
                          flex: entries[index].value,
                          child: Container(
                            key: Key(
                              'analysisChannelBar-${entries[index].key}',
                            ),
                            height: 14,
                            color: _channelColor(index),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (var index = 0; index < entries.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _channelColor(index),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _channelName(channels, entries[index].key),
                          ),
                        ),
                        Text(
                          '${(entries[index].value / snapshot.expense * 100).toStringAsFixed(1)}%・${formatTwd(entries[index].value)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Color _channelColor(int index) => const [
    AppColors.primary,
    AppColors.warning,
    AppColors.expense,
  ][index % 3];

  String _channelName(List<ShoppingChannel> channels, int? id) {
    if (id == null) return '未設定';
    return channels.where((item) => item.id == id).firstOrNull?.name ?? '其他';
  }
}

Category? _categoryById(List<Category> categories, int id) =>
    categories.where((item) => item.id == id).firstOrNull;
