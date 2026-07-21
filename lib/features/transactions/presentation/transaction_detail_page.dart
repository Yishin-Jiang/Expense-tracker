import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/taipei_time.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../channels/presentation/providers/channel_providers.dart';
import '../domain/transaction.dart';
import 'providers/transaction_providers.dart';

class TransactionDetailPage extends ConsumerWidget {
  const TransactionDetailPage({required this.transactionId, super.key});
  final int transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(transactionByIdProvider(transactionId))
        .when(
          data: (transaction) {
            if (transaction == null) {
              return const Center(child: Text('找不到這筆交易'));
            }
            return _DetailBody(transaction: transaction);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('載入交易失敗：$error')),
        );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.transaction});
  final TransactionRecord transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryName = ref
        .watch(categoryByIdProvider(transaction.categoryId))
        .when(
          data: (category) => category?.name ?? '未知類別',
          loading: () => '載入中',
          error: (_, _) => '未知類別',
        );
    final channelName = transaction.channelId == null
        ? null
        : ref
              .watch(channelByIdProvider(transaction.channelId!))
              .when(
                data: (channel) => channel?.name,
                loading: () => '載入中',
                error: (_, _) => null,
              );
    final taipeiDate = toTaipeiTime(transaction.occurredAt);
    final isExpense = transaction.type == TransactionType.expense;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
        children: [
          Text('交易明細', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpense ? '支出' : '收入',
                    style: TextStyle(
                      color: isExpense ? AppColors.expense : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${isExpense ? '−' : '+'} NT\$ ${transaction.amount}',
                    key: const Key('detailAmount'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: isExpense ? AppColors.expense : AppColors.primary,
                    ),
                  ),
                  const Divider(height: 32),
                  _DetailRow(label: '類別', value: categoryName),
                  if (channelName != null)
                    _DetailRow(label: '購物類型', value: channelName),
                  _DetailRow(label: '日期', value: _formatDate(taipeiDate)),
                  _DetailRow(label: '備註', value: transaction.note ?? '沒有備註'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('editTransactionButton'),
            onPressed: () => context.go('/transactions/${transaction.id}/edit'),
            child: const Text('修改這筆記錄'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('deleteTransactionButton'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.expense),
            onPressed: () => _confirmDelete(context, ref),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除這筆記錄？'),
        content: const Text('刪除後將不會出現在交易清單與統計中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(transactionRepositoryProvider)
          .deleteTransaction(transaction.id);
      ref.invalidate(transactionByIdProvider(transaction.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('記錄已刪除')));
      context.go('/home');
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$error')));
    }
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year} / ${two(date.month)} / ${two(date.day)}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
