enum CategoryType { expense, income, both }

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.icon,
    this.color,
  });

  final int id;
  final int? parentId;
  final String name;
  final CategoryType type;
  final String? icon;
  final String? color;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class CategoryInput {
  const CategoryInput({
    required this.name,
    required this.type,
    this.parentId,
    this.icon,
    this.color,
    this.sortOrder = 0,
  });

  final int? parentId;
  final String name;
  final CategoryType type;
  final String? icon;
  final String? color;
  final int sortOrder;

  void validate() {
    if (name.trim().isEmpty) {
      throw const FormatException('類別名稱不能空白');
    }
    if (name.trim().length > 40) {
      throw const FormatException('類別名稱不能超過 40 個字元');
    }
    if (parentId != null && parentId! <= 0) {
      throw const FormatException('父類別識別碼無效');
    }
  }
}

bool categoryMatchesType(Category category, CategoryType type) =>
    category.type == type || category.type == CategoryType.both;

bool categoryHasChildren(Category category, List<Category> categories) =>
    categories.any((item) => item.parentId == category.id);

List<Category> selectableCategories(
  List<Category> categories,
  CategoryType type, {
  int? selectedId,
}) => categories
    .where(
      (item) =>
          categoryMatchesType(item, type) &&
          ((item.isActive && !categoryHasChildren(item, categories)) ||
              item.id == selectedId),
    )
    .toList(growable: false);

Set<int> categoryIdsForSelection(List<Category> categories, int categoryId) {
  final ids = <int>{categoryId};
  var added = true;
  while (added) {
    added = false;
    for (final category in categories) {
      if (category.parentId != null &&
          ids.contains(category.parentId) &&
          ids.add(category.id)) {
        added = true;
      }
    }
  }
  return ids;
}
