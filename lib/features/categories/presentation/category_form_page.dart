import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/category.dart';
import 'category_visuals.dart';
import 'providers/category_providers.dart';

class CategoryFormPage extends ConsumerWidget {
  const CategoryFormPage({this.categoryId, super.key});
  final int? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categoryId == null) return const _CategoryEditor();
    return ref
        .watch(categoryByIdProvider(categoryId!))
        .when(
          data: (category) => category == null
              ? const Center(child: Text('找不到這個類別'))
              : _CategoryEditor(
                  key: ValueKey(category.updatedAt),
                  initialCategory: category,
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('類別載入失敗：$error')),
        );
  }
}

class _CategoryEditor extends ConsumerStatefulWidget {
  const _CategoryEditor({this.initialCategory, super.key});
  final Category? initialCategory;

  @override
  ConsumerState<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<_CategoryEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late CategoryType _type;
  int? _parentId;
  late String _icon;
  late String _color;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final category = widget.initialCategory;
    _nameController = TextEditingController(text: category?.name ?? '');
    _type = category?.type == CategoryType.income
        ? CategoryType.income
        : CategoryType.expense;
    _parentId = category?.parentId;
    _icon = category?.icon ?? 'category';
    _color = category?.color ?? categoryColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialCategory != null;
    final categories = ref.watch(allCategoriesProvider);
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '返回分類管理',
                  onPressed: () => context.go('/categories'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                Text(
                  editing ? '編輯類別' : '新增類別',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              key: const Key('categoryNameField'),
              controller: _nameController,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '類別名稱',
                hintText: '例如：咖啡、娛樂、獎學金',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '請輸入類別名稱' : null,
            ),
            const SizedBox(height: 18),
            Text('收支類型', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SegmentedButton<CategoryType>(
              segments: const [
                ButtonSegment(value: CategoryType.expense, label: Text('支出')),
                ButtonSegment(value: CategoryType.income, label: Text('收入')),
              ],
              selected: {_type},
              onSelectionChanged: editing
                  ? null
                  : (selection) {
                      setState(() {
                        _type = selection.single;
                        _parentId = null;
                      });
                    },
            ),
            if (editing) ...[
              const SizedBox(height: 6),
              Text(
                '為了維持既有交易一致，編輯時不能變更收支類型。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            Text('父類別（選填）', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            categories.when(
              data: (items) {
                final parents = items
                    .where(
                      (item) =>
                          item.isActive &&
                          item.parentId == null &&
                          item.id != widget.initialCategory?.id &&
                          (item.type == _type ||
                              item.type == CategoryType.both),
                    )
                    .toList();
                return DropdownButtonFormField<int?>(
                  key: Key('categoryParent-${_type.name}'),
                  initialValue: _parentId,
                  decoration: const InputDecoration(labelText: '不設定父類別'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('不設定父類別'),
                    ),
                    for (final parent in parents)
                      DropdownMenuItem<int?>(
                        value: parent.id,
                        child: Text(parent.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _parentId = value),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('父類別載入失敗：$error'),
            ),
            const SizedBox(height: 20),
            Text('圖示', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in categoryIcons.entries)
                  ChoiceChip(
                    key: Key('categoryIcon-${entry.key}'),
                    avatar: Icon(entry.value, size: 18),
                    label: const SizedBox(width: 4),
                    selected: _icon == entry.key,
                    onSelected: (_) => setState(() => _icon = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('顏色', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children: [
                for (final color in categoryColors)
                  ChoiceChip(
                    key: Key('categoryColor-$color'),
                    showCheckmark: true,
                    avatar: CircleAvatar(backgroundColor: categoryColor(color)),
                    label: const SizedBox(width: 8),
                    selected: _color == color,
                    onSelected: (_) => setState(() => _color = color),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: FilledButton(
                key: const Key('saveCategoryButton'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(editing ? '儲存修改' : '新增類別'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final all = ref.read(allCategoriesProvider).asData?.value ?? const [];
      final initial = widget.initialCategory;
      final input = CategoryInput(
        name: _nameController.text,
        type: _type,
        parentId: _parentId,
        icon: _icon,
        color: _color,
        sortOrder: initial?.sortOrder ?? (all.length + 1) * 10,
      );
      final repository = ref.read(categoryRepositoryProvider);
      if (initial == null) {
        await repository.createCategory(input);
      } else {
        await repository.updateCategory(initial.id, input);
        ref.invalidate(categoryByIdProvider(initial.id));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(initial == null ? '類別已新增' : '類別已更新')),
      );
      context.go('/categories');
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
