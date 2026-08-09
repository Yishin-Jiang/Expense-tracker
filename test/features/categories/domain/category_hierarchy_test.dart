import 'package:accounting_app/features/categories/domain/category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final categories = [
    _category(id: 1, name: '飲食'),
    _category(id: 2, parentId: 1, name: '午餐'),
    _category(id: 3, parentId: 1, name: '晚餐'),
    _category(id: 4, name: '日用品'),
  ];

  test('only leaf categories are selectable for new transactions', () {
    final selectable = selectableCategories(categories, CategoryType.expense);
    expect(selectable.map((item) => item.name), ['午餐', '晚餐', '日用品']);
  });

  test('a parent selection contains all descendants', () {
    expect(categoryIdsForSelection(categories, 1), {1, 2, 3});
    expect(categoryIdsForSelection(categories, 2), {2});
  });
}

Category _category({required int id, required String name, int? parentId}) =>
    Category(
      id: id,
      parentId: parentId,
      name: name,
      type: CategoryType.expense,
      sortOrder: id,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
