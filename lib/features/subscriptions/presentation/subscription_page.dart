import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../channels/presentation/providers/channel_providers.dart';
import '../domain/subscription.dart';
import 'providers/subscription_providers.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  @override
  Widget build(BuildContext context) {
    ref.listen(processDueSubscriptionsProvider, (previous, next) {
      final count = next.asData?.value ?? 0;
      if (count <= 0 || previous?.asData?.value == count || !mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已自動建立 $count 筆訂閱支出')));
    });
    final processing = ref.watch(processDueSubscriptionsProvider);
    final subscriptions = ref.watch(subscriptionsProvider);
    final summary = ref.watch(subscriptionSummaryProvider);

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
                      '訂閱',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '固定支出先記住，扣款時就不意外',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const Key('addSubscriptionButton'),
                onPressed: () => context.go('/subscriptions/new'),
                icon: const Icon(Icons.add),
                label: const Text('新增'),
              ),
            ],
          ),
          if (processing.isLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 22),
          summary.when(
            data: (data) => _SubscriptionSummaryCard(summary: data),
            loading: () => const SizedBox(
              height: 150,
              child: AppLoadingView(message: '正在計算訂閱支出'),
            ),
            error: (error, _) => AppErrorView(message: '訂閱統計失敗：$error'),
          ),
          const SizedBox(height: 24),
          summary.when(
            data: (data) => _UpcomingSection(items: data.upcoming),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          Text('所有訂閱', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          subscriptions.when(
            data: (items) => items.isEmpty
                ? AppEmptyView(
                    title: '還沒有訂閱項目',
                    message: '新增 Spotify、AI、手機費或網路費，掌握固定支出。',
                    actionLabel: '新增第一筆訂閱',
                    onAction: () => context.go('/subscriptions/new'),
                  )
                : Column(
                    children: [
                      for (final item in items) ...[
                        _SubscriptionCard(
                          subscription: item,
                          onSetActive: _setActive,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
            loading: () => const AppLoadingView(message: '正在載入訂閱'),
            error: (error, _) => AppErrorView(
              message: '訂閱載入失敗：$error',
              onRetry: () => ref.invalidate(subscriptionsProvider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setActive(SubscriptionRecord item, bool active) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('停用「${item.name}」？'),
          content: const Text('停用後不再列入統計，也不會自動建立扣款交易。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認停用'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await ref
          .read(subscriptionRepositoryProvider)
          .setSubscriptionActive(item.id, active);
      if (active) ref.invalidate(processDueSubscriptionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(active ? '訂閱已恢復' : '訂閱已停用')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('操作失敗：$error'),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }
}

class _SubscriptionSummaryCard extends StatelessWidget {
  const _SubscriptionSummaryCard({required this.summary});
  final SubscriptionSummary summary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('每月訂閱估算', style: TextStyle(color: Color(0xFFD9F0E0))),
        const SizedBox(height: 8),
        Text(
          formatTwd(summary.monthlyEstimate),
          key: const Key('subscriptionMonthlyEstimate'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '年度預估 ${formatTwd(summary.annualEstimate)}',
                key: const Key('subscriptionAnnualEstimate'),
                style: const TextStyle(color: Color(0xFFD9F0E0)),
              ),
            ),
            Text(
              '${summary.activeCount} 個啟用中',
              style: const TextStyle(color: Color(0xFFD9F0E0)),
            ),
          ],
        ),
      ],
    ),
  );
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({required this.items});
  final List<SubscriptionRecord> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('七天內扣款', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      if (items.isEmpty)
        Text('近期沒有預定扣款。', style: Theme.of(context).textTheme.bodySmall)
      else
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              for (final item in items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(item.name),
                  subtitle: Text(_formatDate(item.nextBillingDate)),
                  trailing: Text(
                    formatTwd(item.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({
    required this.subscription,
    required this.onSetActive,
  });
  final SubscriptionRecord subscription;
  final Future<void> Function(SubscriptionRecord item, bool active) onSetActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryByIdProvider(subscription.categoryId));
    final channel = subscription.channelId == null
        ? null
        : ref.watch(channelByIdProvider(subscription.channelId!));
    final categoryValue = category.asData?.value;
    return Opacity(
      opacity: subscription.isActive ? 1 : 0.55,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: categoryColor(categoryValue?.color),
                foregroundColor: AppColors.ink,
                child: Icon(categoryIcon(categoryValue?.icon)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subscription.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          formatTwd(subscription.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${billingCycleLabel(subscription.billingCycle)}・下次 ${_formatDate(subscription.nextBillingDate)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SmallChip(label: categoryValue?.name ?? '未分類'),
                        if (channel?.asData?.value case final value?)
                          _SmallChip(label: value.name),
                        if (subscription.autoCreateTransaction)
                          const _SmallChip(label: '自動記帳'),
                        if (!subscription.isActive)
                          const _SmallChip(label: '已停用'),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: Key('subscriptionMenu-${subscription.id}'),
                onSelected: (action) {
                  if (action == 'edit') {
                    context.go('/subscriptions/${subscription.id}/edit');
                  } else {
                    onSetActive(subscription, !subscription.isActive);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('編輯')),
                  PopupMenuItem(
                    value: 'active',
                    child: Text(subscription.isActive ? '停用' : '重新啟用'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label, style: Theme.of(context).textTheme.bodySmall),
  );
}

String billingCycleLabel(BillingCycle cycle) => switch (cycle) {
  BillingCycle.monthly => '月繳',
  BillingCycle.quarterly => '季繳',
  BillingCycle.yearly => '年繳',
};

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}/${two(date.month)}/${two(date.day)}';
}
