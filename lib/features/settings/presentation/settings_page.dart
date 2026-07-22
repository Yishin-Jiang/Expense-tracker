import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../subscriptions/presentation/providers/subscription_providers.dart';
import '../domain/data_management_service.dart';
import 'providers/settings_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(dataSummaryProvider);
    final version = ref.watch(appVersionProvider);

    return SafeArea(
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: '返回首頁',
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 12),
                  Text('設定', style: Theme.of(context).textTheme.headlineMedium),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '管理記帳資料、備份與 App 資訊。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              Text('目前資料', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              summary.when(
                data: (data) => _DataSummaryCard(summary: data),
                loading: () => const SizedBox(
                  height: 118,
                  child: AppLoadingView(message: '正在統計資料'),
                ),
                error: (error, _) => AppErrorView(
                  message: '資料統計失敗：$error',
                  onRetry: () => ref.invalidate(dataSummaryProvider),
                ),
              ),
              const SizedBox(height: 28),
              Text('匯出與備份', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _SettingsAction(
                    key: const Key('exportCsvButton'),
                    icon: Icons.table_view_outlined,
                    title: '匯出交易 CSV',
                    subtitle: '可使用 Excel 或 Google 試算表開啟',
                    onTap: _busy ? null : _exportCsv,
                  ),
                  const Divider(height: 1),
                  _SettingsAction(
                    key: const Key('exportBackupButton'),
                    icon: Icons.cloud_upload_outlined,
                    title: '建立完整備份',
                    subtitle: '包含類別、購物類型、交易與訂閱',
                    onTap: _busy ? null : _exportBackup,
                  ),
                  const Divider(height: 1),
                  _SettingsAction(
                    key: const Key('restoreBackupButton'),
                    icon: Icons.settings_backup_restore,
                    title: '從備份還原',
                    subtitle: '選擇由本 App 建立的 JSON 備份檔',
                    onTap: _busy ? null : _restoreBackup,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text('資料重設', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _SettingsAction(
                    key: const Key('clearDataButton'),
                    icon: Icons.delete_sweep_outlined,
                    iconColor: AppColors.expense,
                    title: '清除全部資料',
                    subtitle: '刪除記錄並恢復預設類別，無法復原',
                    onTap: _busy ? null : _clearData,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text('關於', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('學生記帳'),
                    subtitle: version.when(
                      data: (data) => Text(
                        '版本 ${data.version}（${data.buildNumber}）',
                        key: const Key('appVersionText'),
                      ),
                      loading: () => const Text('正在讀取版本'),
                      error: (_, _) => const Text('版本資訊無法讀取'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_busy)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Future<void> _exportCsv() => _runAction(
    () => ref.read(dataManagementServiceProvider).exportTransactionsCsv(),
    successMessage: 'CSV 已建立，請完成儲存。',
  );

  Future<void> _exportBackup() => _runAction(
    () => ref.read(dataManagementServiceProvider).exportBackup(),
    successMessage: '完整備份已建立，請妥善保存。',
  );

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('從備份還原？'),
        content: const Text('目前所有資料會被備份檔取代。建議先建立一份最新備份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirmRestoreButton'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('選擇備份檔'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runAction(
      () async {
        final result = await ref
            .read(dataManagementServiceProvider)
            .pickAndRestoreBackup();
        if (result == null) return null;
        _refreshData();
        return result;
      },
      successMessage: '資料已成功還原。',
      showSuccessWhenNull: false,
    );
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除全部資料？'),
        content: const Text('所有交易、訂閱及自訂類別都會被刪除，並恢復預設類別。這個動作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirmClearDataButton'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runAction(() async {
      await ref.read(dataManagementServiceProvider).clearAllData();
      _refreshData();
    }, successMessage: '資料已清除，預設類別已恢復。');
  }

  Future<void> _runAction<T>(
    Future<T> Function() action, {
    required String successMessage,
    bool showSuccessWhenNull = true,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await action();
      if (!mounted || (!showSuccessWhenNull && result == null)) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(error)),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refreshData() {
    ref.invalidate(dataSummaryProvider);
    ref.invalidate(processDueSubscriptionsProvider);
  }

  String _errorMessage(Object error) {
    if (error is BackupFormatException) return error.message;
    return '操作失敗：$error';
  }
}

class _DataSummaryCard extends StatelessWidget {
  const _DataSummaryCard({required this.summary});

  final DataSummary summary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        _SummaryItem(label: '交易', value: summary.transactionCount),
        _SummaryItem(label: '類別', value: summary.categoryCount),
        _SummaryItem(label: '訂閱', value: summary.subscriptionCount),
      ],
    ),
  );
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFFD9F0E0))),
      ],
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.divider),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = AppColors.primary,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: iconColor),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    enabled: onTap != null,
    onTap: onTap,
  );
}
