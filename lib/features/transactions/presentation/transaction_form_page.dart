import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/taipei_time.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../channels/presentation/providers/channel_providers.dart';
import '../domain/transaction.dart';
import 'providers/transaction_providers.dart';

class TransactionFormPage extends ConsumerWidget {
  const TransactionFormPage({this.transactionId, super.key});

  final int? transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactionId == null) {
      return const _TransactionEditor();
    }

    return ref
        .watch(transactionByIdProvider(transactionId!))
        .when(
          data: (transaction) {
            if (transaction == null) {
              return const _FormMessage(message: '找不到這筆交易');
            }
            return _TransactionEditor(
              key: ValueKey(transaction.updatedAt),
              initialTransaction: transaction,
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _FormMessage(message: '載入交易失敗：$error'),
        );
  }
}

class _TransactionEditor extends ConsumerStatefulWidget {
  const _TransactionEditor({super.key, this.initialTransaction});

  final TransactionRecord? initialTransaction;

  @override
  ConsumerState<_TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends ConsumerState<_TransactionEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late TransactionType _type;
  late DateTime _occurredAt;
  int? _categoryId;
  int? _channelId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTransaction;
    _amountController = TextEditingController(
      text: initial?.amount.toString() ?? '',
    );
    _noteController = TextEditingController(text: initial?.note ?? '');
    _type = initial?.type ?? TransactionType.expense;
    _categoryId = initial?.categoryId;
    _channelId = initial?.channelId;
    _occurredAt = initial == null
        ? toTaipeiTime(DateTime.now())
        : toTaipeiTime(initial.occurredAt);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryType = _type == TransactionType.expense
        ? CategoryType.expense
        : CategoryType.income;
    final categories = ref.watch(activeCategoriesProvider(categoryType));
    final channels = ref.watch(activeChannelsProvider);
    final editing = widget.initialTransaction != null;

    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            Text(
              editing ? '修改記錄' : '新增一筆',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '支出／收入都能在這裡快速完成',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('支出'),
                ),
                ButtonSegment(value: TransactionType.income, label: Text('收入')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() {
                  _type = selection.single;
                  _categoryId = null;
                  if (_type == TransactionType.income) _channelId = null;
                });
              },
              style: const ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(AppColors.surface),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              key: const Key('amountField'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                labelText: '金額',
                prefixText: 'NT\$ ',
              ),
              validator: (value) {
                final amount = int.tryParse(value ?? '');
                return amount == null || amount <= 0 ? '請輸入大於 0 的金額' : null;
              },
            ),
            const SizedBox(height: 20),
            Text('類別', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            categories.when(
              data: (items) => DropdownButtonFormField<int>(
                key: ValueKey('category-${_type.name}'),
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: '選擇類別'),
                items: [
                  for (final item in items)
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) => value == null ? '請選擇類別' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('類別載入失敗：$error'),
            ),
            if (_type == TransactionType.expense) ...[
              const SizedBox(height: 20),
              Text('購物類型', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              channels.when(
                data: (items) => Wrap(
                  spacing: 10,
                  children: [
                    for (final item in items)
                      ChoiceChip(
                        label: Text(item.name),
                        selected: _channelId == item.id,
                        onSelected: (_) => setState(() => _channelId = item.id),
                      ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('購物類型載入失敗：$error'),
              ),
            ],
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                key: const Key('dateField'),
                title: const Text('日期'),
                subtitle: Text(_formatDate(_occurredAt)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('noteField'),
              controller: _noteController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '備註',
                hintText: '例如：學校第二餐廳',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              child: FilledButton(
                key: const Key('saveTransactionButton'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(editing ? '儲存修改' : '儲存這筆記錄'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final categoryId = _categoryId;
    if (categoryId == null) return;

    setState(() => _saving = true);
    try {
      final input = TransactionInput(
        categoryId: categoryId,
        channelId: _type == TransactionType.expense ? _channelId : null,
        type: _type,
        amount: int.parse(_amountController.text),
        occurredAt: toUtcFromTaipei(_occurredAt),
        note: _noteController.text,
      );
      final repository = ref.read(transactionRepositoryProvider);
      final saved = widget.initialTransaction == null
          ? await repository.createTransaction(input)
          : await repository.updateTransaction(
              widget.initialTransaction!.id,
              input,
            );
      ref.invalidate(transactionByIdProvider(saved.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.initialTransaction == null ? '記錄已新增' : '記錄已更新'),
        ),
      );
      context.go('/transactions/${saved.id}');
    } on TransactionValidationException catch (error) {
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

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year} / ${two(date.month)} / ${two(date.day)}';
  }
}

class _FormMessage extends StatelessWidget {
  const _FormMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(child: Text(message));
}
