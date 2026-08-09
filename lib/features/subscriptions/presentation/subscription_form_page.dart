import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../channels/presentation/providers/channel_providers.dart';
import '../domain/subscription.dart';
import 'providers/subscription_providers.dart';

class SubscriptionFormPage extends ConsumerWidget {
  const SubscriptionFormPage({this.subscriptionId, super.key});
  final int? subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subscriptionId == null) return const _SubscriptionEditor();
    return ref
        .watch(subscriptionByIdProvider(subscriptionId!))
        .when(
          data: (item) => item == null
              ? const Center(child: Text('找不到這個訂閱'))
              : _SubscriptionEditor(
                  key: ValueKey(item.updatedAt),
                  initialSubscription: item,
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('訂閱載入失敗：$error')),
        );
  }
}

class _SubscriptionEditor extends ConsumerStatefulWidget {
  const _SubscriptionEditor({this.initialSubscription, super.key});
  final SubscriptionRecord? initialSubscription;

  @override
  ConsumerState<_SubscriptionEditor> createState() =>
      _SubscriptionEditorState();
}

class _SubscriptionEditorState extends ConsumerState<_SubscriptionEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late BillingCycle _cycle;
  late DateTime _startDate;
  DateTime? _endDate;
  late DateTime _nextBillingDate;
  int? _categoryId;
  int? _channelId;
  bool _autoCreate = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialSubscription;
    final today = ref.read(subscriptionTodayProvider);
    _nameController = TextEditingController(text: item?.name ?? '');
    _amountController = TextEditingController(
      text: item?.amount.toString() ?? '',
    );
    _noteController = TextEditingController(text: item?.note ?? '');
    _cycle = item?.billingCycle ?? BillingCycle.monthly;
    _startDate =
        item?.startDate ?? DateTime(today.year, today.month, today.day);
    _endDate = item?.endDate;
    _nextBillingDate = item?.nextBillingDate ?? _startDate;
    _categoryId = item?.categoryId;
    _channelId = item?.channelId;
    _autoCreate = item?.autoCreateTransaction ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialSubscription != null;
    final categories = ref.watch(allCategoriesProvider);
    final channels = ref.watch(allChannelsProvider);
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '返回訂閱',
                  onPressed: () => context.go('/subscriptions'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                Text(
                  editing ? '編輯訂閱' : '新增訂閱',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              key: const Key('subscriptionNameField'),
              controller: _nameController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: '訂閱名稱',
                hintText: '例如：Spotify、AI、手機網路費',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '請輸入訂閱名稱' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('subscriptionAmountField'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '每期金額',
                prefixText: 'NT\$ ',
              ),
              validator: (value) {
                final amount = int.tryParse(value ?? '');
                return amount == null || amount <= 0 ? '請輸入大於 0 的金額' : null;
              },
            ),
            const SizedBox(height: 20),
            Text('扣款週期', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SegmentedButton<BillingCycle>(
              segments: const [
                ButtonSegment(value: BillingCycle.monthly, label: Text('月繳')),
                ButtonSegment(value: BillingCycle.quarterly, label: Text('季繳')),
                ButtonSegment(value: BillingCycle.yearly, label: Text('年繳')),
              ],
              selected: {_cycle},
              onSelectionChanged: (selection) {
                setState(() => _cycle = selection.single);
              },
            ),
            const SizedBox(height: 20),
            Text('支出類別', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            categories.when(
              data: (items) {
                final expenseCategories = selectableCategories(
                  items,
                  CategoryType.expense,
                  selectedId: editing ? _categoryId : null,
                );
                return DropdownButtonFormField<int>(
                  key: const Key('subscriptionCategoryField'),
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: '選擇支出類別'),
                  items: [
                    for (final item in expenseCategories)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          item.isActive ? item.name : '${item.name}（已停用）',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (value) => value == null ? '請選擇支出類別' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('類別載入失敗：$error'),
            ),
            const SizedBox(height: 20),
            Text('購物管道（選填）', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            channels.when(
              data: (items) => DropdownButtonFormField<int?>(
                key: const Key('subscriptionChannelField'),
                initialValue: _channelId,
                decoration: const InputDecoration(labelText: '選擇購物管道'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('不設定')),
                  for (final item in items.where(
                    (item) => item.isActive || item.id == _channelId,
                  ))
                    DropdownMenuItem<int?>(
                      value: item.id,
                      child: Text(
                        item.isActive ? item.name : '${item.name}（已停用）',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _channelId = value),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('購物管道載入失敗：$error'),
            ),
            const SizedBox(height: 20),
            _DateField(
              fieldKey: const Key('subscriptionStartDateField'),
              label: '開始日期',
              date: _startDate,
              onTap: () => _pickDate(
                initial: _startDate,
                onSelected: (date) => setState(() => _startDate = date),
              ),
            ),
            const SizedBox(height: 10),
            _DateField(
              fieldKey: const Key('subscriptionNextBillingDateField'),
              label: '下次扣款日',
              date: _nextBillingDate,
              onTap: () => _pickDate(
                initial: _nextBillingDate,
                onSelected: (date) {
                  setState(() => _nextBillingDate = date);
                },
              ),
            ),
            const SizedBox(height: 10),
            _DateField(
              fieldKey: const Key('subscriptionEndDateField'),
              label: '結束日期（選填）',
              date: _endDate,
              onTap: () => _pickDate(
                initial: _endDate ?? _nextBillingDate,
                onSelected: (date) => setState(() => _endDate = date),
              ),
              onClear: _endDate == null
                  ? null
                  : () => setState(() => _endDate = null),
            ),
            const SizedBox(height: 16),
            Card(
              child: SwitchListTile(
                key: const Key('subscriptionAutoCreateSwitch'),
                title: const Text('扣款日自動建立支出'),
                subtitle: const Text('開啟 App 時，會補上已到期的訂閱交易'),
                value: _autoCreate,
                onChanged: (value) => setState(() => _autoCreate = value),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('subscriptionNoteField'),
              controller: _noteController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '備註',
                hintText: '例如：學生方案、家庭共享',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              child: FilledButton(
                key: const Key('saveSubscriptionButton'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(editing ? '儲存修改' : '新增訂閱'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) onSelected(selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final categoryId = _categoryId;
    if (categoryId == null) return;
    setState(() => _saving = true);
    try {
      final input = SubscriptionInput(
        categoryId: categoryId,
        channelId: _channelId,
        name: _nameController.text,
        amount: int.parse(_amountController.text),
        billingCycle: _cycle,
        startDate: _startDate,
        endDate: _endDate,
        nextBillingDate: _nextBillingDate,
        note: _noteController.text,
        autoCreateTransaction: _autoCreate,
      );
      final repository = ref.read(subscriptionRepositoryProvider);
      final initial = widget.initialSubscription;
      if (initial == null) {
        await repository.createSubscription(input);
      } else {
        await repository.updateSubscription(initial.id, input);
        ref.invalidate(subscriptionByIdProvider(initial.id));
      }
      ref.invalidate(processDueSubscriptionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(initial == null ? '訂閱已新增' : '訂閱已更新')),
      );
      context.go('/subscriptions');
    } on FormatException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('儲存失敗：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.expense),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.fieldKey,
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });
  final Key fieldKey;
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      key: fieldKey,
      title: Text(label),
      subtitle: Text(date == null ? '未設定' : _formatDate(date!)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onClear != null)
            IconButton(
              tooltip: '清除日期',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
          const Icon(Icons.calendar_month_outlined),
        ],
      ),
      onTap: onTap,
    ),
  );
}

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year} / ${two(date.month)} / ${two(date.day)}';
}
