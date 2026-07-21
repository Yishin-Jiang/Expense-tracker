import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/taipei_time.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../channels/presentation/providers/channel_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/calendar_month_snapshot.dart';
import 'providers/calendar_providers.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _displayedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final today = ref.read(calendarTodayProvider);
    _displayedMonth = DateTime(today.year, today.month);
    _selectedDate = DateTime(today.year, today.month, today.day);
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(calendarTodayProvider);
    final monthData = ref.watch(calendarMonthProvider(_displayedMonth));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '月曆',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '每天的花費，一眼就知道',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('calendarTodayButton'),
                onPressed: () => _goToToday(today),
                child: const Text('回到今天'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          monthData.when(
            data: (snapshot) => Column(
              children: [
                _MonthSummary(snapshot: snapshot),
                const SizedBox(height: 16),
                _CalendarCard(
                  snapshot: snapshot,
                  selectedDate: _selectedDate,
                  today: today,
                  onPrevious: () => _changeMonth(-1),
                  onNext: () => _changeMonth(1),
                  onSelect: (date) => setState(() => _selectedDate = date),
                ),
                const SizedBox(height: 24),
                _SelectedDaySection(
                  summary: snapshot.summaryFor(_selectedDate),
                  onAdd: () => context.go(
                    '/transactions/new?date=${_dateParameter(_selectedDate)}',
                  ),
                ),
              ],
            ),
            loading: () => const AppLoadingView(message: '正在整理本月紀錄'),
            error: (error, _) => AppErrorView(
              message: '月曆載入失敗：$error',
              onRetry: () =>
                  ref.invalidate(calendarMonthProvider(_displayedMonth)),
            ),
          ),
        ],
      ),
    );
  }

  void _changeMonth(int offset) {
    final month = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + offset,
    );
    setState(() {
      _displayedMonth = month;
      _selectedDate = DateTime(month.year, month.month);
    });
  }

  void _goToToday(DateTime today) {
    setState(() {
      _displayedMonth = DateTime(today.year, today.month);
      _selectedDate = DateTime(today.year, today.month, today.day);
    });
  }

  String _dateParameter(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.snapshot});
  final CalendarMonthSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('calendarMonthSummary'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Expanded(
          child: _SummaryValue(
            label: '本月支出',
            value: formatTwd(snapshot.expense),
            valueKey: const Key('calendarMonthExpense'),
          ),
        ),
        Container(width: 1, height: 48, color: const Color(0xFF47806B)),
        const SizedBox(width: 18),
        Expanded(
          child: _SummaryValue(
            label: '本月收入',
            value: formatTwd(snapshot.income),
            valueKey: const Key('calendarMonthIncome'),
          ),
        ),
      ],
    ),
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.valueKey,
  });
  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Color(0xFFD9F0E0))),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          key: valueKey,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.snapshot,
    required this.selectedDate,
    required this.today,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  final CalendarMonthSnapshot snapshot;
  final DateTime selectedDate;
  final DateTime today;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  static const weekDays = ['日', '一', '二', '三', '四', '五', '六'];

  @override
  Widget build(BuildContext context) {
    final month = snapshot.month;
    final firstWeekday = DateTime(month.year, month.month).weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final usedCells = firstWeekday + daysInMonth;
    final cellCount = ((usedCells + 6) ~/ 7) * 7;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('previousMonthButton'),
                  tooltip: '上個月',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${month.year} 年 ${month.month} 月',
                    key: const Key('calendarMonthTitle'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('nextMonthButton'),
                  tooltip: '下個月',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var index = 0; index < weekDays.length; index++)
                  Expanded(
                    child: Text(
                      weekDays[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: index == 0 || index == 6
                            ? AppColors.expense
                            : AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.82,
              ),
              itemCount: cellCount,
              itemBuilder: (context, index) {
                final day = index - firstWeekday + 1;
                if (day < 1 || day > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final date = DateTime(month.year, month.month, day);
                return _CalendarDay(
                  date: date,
                  summary: snapshot.days[day],
                  selected: _sameDay(date, selectedDate),
                  isToday: _sameDay(date, today),
                  onTap: () => onSelect(date),
                );
              },
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: AppColors.expense, label: '支出'),
                SizedBox(width: 18),
                _LegendDot(color: AppColors.primary, label: '收入'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.summary,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final CalendarDaySummary? summary;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('calendarDay-${date.year}-${date.month}-${date.day}'),
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isToday && !selected
            ? Border.all(color: AppColors.primary)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              color: selected ? Colors.white : AppColors.ink,
              fontWeight: selected || isToday
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if ((summary?.expense ?? 0) > 0)
                  _dot(
                    selected ? AppColors.expenseContainer : AppColors.expense,
                  ),
                if ((summary?.expense ?? 0) > 0 && (summary?.income ?? 0) > 0)
                  const SizedBox(width: 3),
                if ((summary?.income ?? 0) > 0)
                  _dot(
                    selected ? AppColors.primaryContainer : AppColors.primary,
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _dot(Color color) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _SelectedDaySection extends StatelessWidget {
  const _SelectedDaySection({required this.summary, required this.onAdd});
  final CalendarDaySummary summary;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary.date.month} 月 ${summary.date.day} 日紀錄',
                  key: const Key('selectedDateTitle'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.transactionCount} 筆・支出 ${formatTwd(summary.expense)}・收入 ${formatTwd(summary.income)}',
                  key: const Key('selectedDateSummary'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          FilledButton.icon(
            key: const Key('addTransactionForDateButton'),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('記一筆'),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (summary.transactions.isEmpty)
        AppEmptyView(
          title: '這天沒有紀錄',
          message: '選擇其他日期，或新增一筆交易。',
          actionLabel: '新增這天的交易',
          onAction: onAdd,
        )
      else
        Card(
          child: Column(
            children: [
              for (
                var index = 0;
                index < summary.transactions.length;
                index++
              ) ...[
                _CalendarTransactionTile(
                  transaction: summary.transactions[index],
                ),
                if (index < summary.transactions.length - 1)
                  const Divider(height: 1, indent: 64),
              ],
            ],
          ),
        ),
    ],
  );
}

class _CalendarTransactionTile extends ConsumerWidget {
  const _CalendarTransactionTile({required this.transaction});
  final TransactionRecord transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryByIdProvider(transaction.categoryId));
    final channel = transaction.channelId == null
        ? null
        : ref.watch(channelByIdProvider(transaction.channelId!));
    final isExpense = transaction.type == TransactionType.expense;
    final localDate = toTaipeiTime(transaction.occurredAt);
    final name = category.asData?.value?.name ?? '未分類';
    final channelName = channel?.asData?.value?.name;
    final note = transaction.note;
    final details = [
      '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}',
      ?channelName,
      if (note != null && note.isNotEmpty) note,
    ].join('・');

    return ListTile(
      key: Key('calendarTransaction-${transaction.id}'),
      leading: CircleAvatar(
        backgroundColor: categoryColor(category.asData?.value?.color),
        foregroundColor: AppColors.ink,
        child: Icon(categoryIcon(category.asData?.value?.icon)),
      ),
      title: Text(name),
      subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '${isExpense ? '−' : '+'} ${formatTwd(transaction.amount)}',
        style: TextStyle(
          color: isExpense ? AppColors.expense : AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: () => context.go('/transactions/${transaction.id}'),
    );
  }
}
