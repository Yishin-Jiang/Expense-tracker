import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../channels/presentation/channel_management_view.dart';
import '../domain/category.dart';
import 'category_visuals.dart';
import 'providers/category_providers.dart';

class CategoryManagementPage extends ConsumerStatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  ConsumerState<CategoryManagementPage> createState() =>
      _CategoryManagementPageState();
}

class _CategoryManagementPageState
    extends ConsumerState<CategoryManagementPage> {
  _ManagementSection _section = _ManagementSection.categories;
  CategoryType _type = CategoryType.expense;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(allCategoriesProvider);
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
                  '分類管理',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Text(
              '管理記帳使用的收支類別與購物管道',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 22),
          SegmentedButton<_ManagementSection>(
            segments: const [
              ButtonSegment(
                value: _ManagementSection.categories,
                icon: Icon(Icons.category_outlined),
                label: Text('收支類別'),
              ),
              ButtonSegment(
                value: _ManagementSection.channels,
                icon: Icon(Icons.storefront_outlined),
                label: Text('購物管道'),
              ),
            ],
            selected: {_section},
            onSelectionChanged: (selection) {
              setState(() => _section = selection.single);
            },
          ),
          const SizedBox(height: 20),
          if (_section == _ManagementSection.channels)
            const ChannelManagementView()
          else ...[
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<CategoryType>(
                    segments: const [
                      ButtonSegment(
                        value: CategoryType.expense,
                        label: Text('支出'),
                      ),
                      ButtonSegment(
                        value: CategoryType.income,
                        label: Text('收入'),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selection) {
                      setState(() => _type = selection.single);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const Key('addCategoryButton'),
                  onPressed: () => context.go('/categories/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('新增'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            categories.when(
              data: (items) {
                final visible = items
                    .where(
                      (item) =>
                          item.type == _type || item.type == CategoryType.both,
                    )
                    .toList();
                if (visible.isEmpty) {
                  return AppEmptyView(
                    title: '還沒有類別',
                    message: '新增一個類別，讓每筆收支更容易整理。',
                    actionLabel: '新增類別',
                    onAction: () => context.go('/categories/new'),
                  );
                }
                return _CategoryList(
                  categories: visible,
                  onSetActive: _setActive,
                );
              },
              loading: () => const AppLoadingView(message: '正在載入類別'),
              error: (error, _) => AppErrorView(
                message: '類別載入失敗：$error',
                onRetry: () => ref.invalidate(allCategoriesProvider),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setActive(Category category, bool active) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('停用「${category.name}」？'),
          content: const Text('之後新增記帳時不會再顯示，但既有交易與統計會完整保留。'),
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
      final repository = ref.read(categoryRepositoryProvider);
      if (active) {
        await repository.restoreCategory(category.id);
      } else {
        await repository.archiveCategory(category.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(active ? '類別已啟用' : '類別已停用')));
    } on FormatException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('操作失敗：$error');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.expense),
    );
  }
}

enum _ManagementSection { categories, channels }

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories, required this.onSetActive});

  final List<Category> categories;
  final Future<void> Function(Category category, bool active) onSetActive;

  @override
  Widget build(BuildContext context) {
    final roots = categories.where((item) => item.parentId == null).toList();
    final orphaned = categories
        .where(
          (item) =>
              item.parentId != null &&
              !categories.any((parent) => parent.id == item.parentId),
        )
        .toList();

    return Column(
      children: [
        for (final category in [...roots, ...orphaned]) ...[
          _CategoryCard(
            category: category,
            children: categories
                .where((item) => item.parentId == category.id)
                .toList(),
            onSetActive: onSetActive,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.children,
    required this.onSetActive,
  });

  final Category category;
  final List<Category> children;
  final Future<void> Function(Category category, bool active) onSetActive;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        _CategoryTile(category: category, onSetActive: onSetActive),
        for (final child in children) ...[
          const Divider(height: 1, indent: 64),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: _CategoryTile(
              category: child,
              onSetActive: onSetActive,
              isChild: true,
            ),
          ),
        ],
      ],
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onSetActive,
    this.isChild = false,
  });

  final Category category;
  final Future<void> Function(Category category, bool active) onSetActive;
  final bool isChild;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: category.isActive ? 1 : 0.55,
    child: ListTile(
      key: Key('category-${category.id}'),
      leading: CircleAvatar(
        backgroundColor: categoryColor(category.color),
        foregroundColor: AppColors.ink,
        child: Icon(categoryIcon(category.icon)),
      ),
      title: Text(category.name),
      subtitle: Text(
        category.isActive ? (isChild ? '子類別' : '主要類別') : '已停用・歷史資料保留',
      ),
      trailing: PopupMenuButton<String>(
        key: Key('categoryMenu-${category.id}'),
        onSelected: (action) {
          if (action == 'edit') {
            context.go('/categories/${category.id}/edit');
          } else {
            onSetActive(category, !category.isActive);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('編輯')),
          PopupMenuItem(
            value: 'active',
            child: Text(category.isActive ? '停用' : '重新啟用'),
          ),
        ],
      ),
    ),
  );
}
