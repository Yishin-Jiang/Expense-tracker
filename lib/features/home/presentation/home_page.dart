import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/taipei_time.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../channels/presentation/providers/channel_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/home_snapshot.dart';
import 'providers/home_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(currentTaipeiDateProvider);
    final snapshot = ref.watch(homeSnapshotProvider);
    final categories = ref.watch(
      activeCategoriesProvider(CategoryType.expense),
    );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeSnapshotProvider);
          await ref.read(homeSnapshotProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${today.month} 月 ${today.day} 日',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton.filledTonal(
                  key: const Key('transactionHistoryButton'),
                  tooltip: '搜尋交易',
                  onPressed: () => context.go('/transactions/history'),
                  icon: const Icon(Icons.search),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  key: const Key('manageCategoriesButton'),
                  tooltip: '管理分類',
                  onPressed: () => context.go('/categories'),
                  icon: const Icon(Icons.category_outlined),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  key: const Key('settingsButton'),
                  tooltip: '設定',
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '所有資料只會儲存在你的裝置中',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            snapshot.when(
              data: (data) => _MonthlySummaryCard(snapshot: data),
              loading: () => const _SummaryLoadingCard(),
              error: (error, _) => AppErrorView(
                message: '本月摘要載入失敗：$error',
                onRetry: () => ref.invalidate(homeSnapshotProvider),
              ),
            ),
            const SizedBox(height: 26),
            _SectionTitle(title: '快速記帳', action: '選好類別，直接輸入金額'),
            const SizedBox(height: 12),
            categories.when(
              data: (items) => _QuickEntries(categories: items),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('快速分類載入失敗：$error'),
            ),
            const SizedBox(height: 28),
            snapshot.when(
              data: (data) => _TransactionSection(
                title: '今天的紀錄',
                summary:
                    '共 ${data.todayCount} 筆・支出 ${formatTwd(data.todayExpense)}',
                transactions: data.todayTransactions,
                empty: AppEmptyView(
                  title: '還沒有記帳紀錄',
                  message: '新增第一筆收入或支出，開始掌握自己的生活費。',
                  actionLabel: '新增一筆',
                  onAction: () => context.go('/transactions/new'),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 28),
            snapshot.when(
              data: (data) => _TransactionSection(
                title: '最近交易',
                summary: '本月最近 ${data.recentTransactions.length} 筆',
                transactions: data.recentTransactions,
                empty: const Text('新增記錄後，最近交易會顯示在這裡。'),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({required this.snapshot});
  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final progress = snapshot.monthIncome == 0
        ? 0.0
        : (snapshot.monthExpense / snapshot.monthIncome).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('本月支出', style: TextStyle(color: Color(0xFFD9F0E0))),
          const SizedBox(height: 10),
          Text(
            formatTwd(snapshot.monthExpense),
            key: const Key('monthlyExpense'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '收入 ${formatTwd(snapshot.monthIncome)}　結餘 ${formatTwd(snapshot.balance)}',
            style: const TextStyle(color: Color(0xFFD9F0E0)),
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFF47806B),
            color: AppColors.warning,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          const SizedBox(height: 8),
          const Text(
            '支出占本月收入比例',
            style: TextStyle(color: Color(0xFFD9F0E0), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SummaryLoadingCard extends StatelessWidget {
  const _SummaryLoadingCard();

  @override
  Widget build(BuildContext context) => Container(
    height: 178,
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(24),
    ),
    alignment: Alignment.center,
    child: const CircularProgressIndicator(color: Colors.white),
  );
}

class _QuickEntries extends StatelessWidget {
  const _QuickEntries({required this.categories});
  final List<Category> categories;

  static const names = ['早餐', '午餐', '晚餐', '日用品'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < names.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: _quickButton(context, names[index])),
        ],
      ],
    );
  }

  Widget _quickButton(BuildContext context, String name) {
    Category? category;
    for (final item in categories) {
      if (item.name == name) {
        category = item;
        break;
      }
    }
    return FilledButton.tonal(
      key: Key('quickEntry-$name'),
      onPressed: category == null
          ? null
          : () => context.go('/transactions/new?categoryId=${category!.id}'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      ),
      child: Text(name),
    );
  }
}

class _TransactionSection extends StatelessWidget {
  const _TransactionSection({
    required this.title,
    required this.summary,
    required this.transactions,
    required this.empty,
  });

  final String title;
  final String summary;
  final List<TransactionRecord> transactions;
  final Widget empty;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(title: title, action: summary),
      const SizedBox(height: 12),
      if (transactions.isEmpty)
        empty
      else
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < transactions.length; index++) ...[
                _TransactionTile(transaction: transactions[index]),
                if (index < transactions.length - 1)
                  const Divider(height: 1, indent: 64),
              ],
            ],
          ),
        ),
    ],
  );
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction});
  final TransactionRecord transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryByIdProvider(transaction.categoryId));
    final channel = transaction.channelId == null
        ? null
        : ref.watch(channelByIdProvider(transaction.channelId!));
    final isExpense = transaction.type == TransactionType.expense;
    final localDate = toTaipeiTime(transaction.occurredAt);
    final categoryName = category.asData?.value?.name ?? '未分類';
    final channelName = channel?.asData?.value?.name;
    final note = transaction.note;
    final details = [
      '${localDate.month}/${localDate.day} ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}',
      ?channelName,
      if (note != null && note.isNotEmpty) note,
    ].join('・');

    return ListTile(
      key: Key('homeTransaction-${transaction.id}'),
      leading: CircleAvatar(
        backgroundColor: isExpense
            ? AppColors.expenseContainer
            : AppColors.primaryContainer,
        foregroundColor: isExpense ? AppColors.expense : AppColors.primary,
        child: Icon(isExpense ? Icons.arrow_upward : Icons.arrow_downward),
      ),
      title: Text(categoryName),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action});
  final String title;
  final String action;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const Spacer(),
      Flexible(
        child: Text(
          action,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}
