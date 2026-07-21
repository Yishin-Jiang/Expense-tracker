import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../domain/category.dart';
import '../domain/category_repository.dart';

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._database);
  final db.AppDatabase _database;

  @override
  Stream<List<Category>> watchAllCategories() {
    return _database.categoryDao.watchAllCategories().map(
      (items) => items.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Future<Category?> getCategory(int id) async {
    final item = await (_database.select(
      _database.categories,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return item == null ? null : _toDomain(item);
  }

  @override
  Stream<List<Category>> watchActiveCategories(CategoryType type) {
    return _database.categoryDao
        .watchActiveCategories(type.name)
        .map((items) => items.map(_toDomain).toList(growable: false));
  }

  @override
  Future<Category> createCategory(CategoryInput input) async {
    input.validate();
    await _validateRelationships(input);
    final id = await _database.categoryDao.createCategory(
      db.CategoriesCompanion.insert(
        parentId: Value(input.parentId),
        name: input.name.trim(),
        type: Value(input.type.name),
        icon: Value(input.icon),
        color: Value(input.color),
        sortOrder: Value(input.sortOrder),
      ),
    );
    return _getRequired(id);
  }

  @override
  Future<Category> updateCategory(int id, CategoryInput input) async {
    input.validate();
    final current = await (_database.select(
      _database.categories,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (current == null) throw StateError('找不到類別 $id');
    await _validateRelationships(input, categoryId: id);

    await _database.categoryDao.updateCategory(
      current.copyWith(
        parentId: Value(input.parentId),
        name: input.name.trim(),
        type: input.type.name,
        icon: Value(input.icon),
        color: Value(input.color),
        sortOrder: input.sortOrder,
      ),
    );
    return _getRequired(id);
  }

  @override
  Future<void> archiveCategory(int id) async {
    final childQuery = _database.select(_database.categories)
      ..where((row) => row.parentId.equals(id) & row.isActive.equals(true))
      ..limit(1);
    final activeChild = await childQuery.getSingleOrNull();
    if (activeChild != null) {
      throw const FormatException('請先停用這個類別下的子類別');
    }
    if (await _database.categoryDao.archiveCategory(id) != 1) {
      throw StateError('找不到類別 $id');
    }
  }

  @override
  Future<void> restoreCategory(int id) async {
    final current = await (_database.select(
      _database.categories,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (current == null) throw StateError('找不到類別 $id');
    if (current.parentId != null) {
      final parent = await (_database.select(
        _database.categories,
      )..where((row) => row.id.equals(current.parentId!))).getSingleOrNull();
      if (parent == null || !parent.isActive) {
        throw const FormatException('請先啟用父類別');
      }
    }
    if (await _database.categoryDao.setCategoryActive(id, true) != 1) {
      throw StateError('找不到類別 $id');
    }
  }

  Future<void> _validateRelationships(
    CategoryInput input, {
    int? categoryId,
  }) async {
    if (categoryId != null && input.parentId == categoryId) {
      throw const FormatException('類別不能把自己設為父類別');
    }

    if (input.parentId != null) {
      if (categoryId != null) {
        final childQuery = _database.select(_database.categories)
          ..where((row) => row.parentId.equals(categoryId))
          ..limit(1);
        if (await childQuery.getSingleOrNull() != null) {
          throw const FormatException('有子類別的類別不能再設定父類別');
        }
      }
      final parent = await (_database.select(
        _database.categories,
      )..where((row) => row.id.equals(input.parentId!))).getSingleOrNull();
      if (parent == null || !parent.isActive) {
        throw const FormatException('找不到可使用的父類別');
      }
      if (parent.parentId != null) {
        throw const FormatException('目前最多支援兩層類別');
      }
      if (parent.type != 'both' && parent.type != input.type.name) {
        throw const FormatException('父類別與子類別的收支類型必須一致');
      }
    }

    final normalizedName = input.name.trim().toLowerCase();
    final existing =
        await (_database.select(_database.categories)..where(
              (row) =>
                  row.name.lower().equals(normalizedName) &
                  row.type.equals(input.type.name),
            ))
            .get();
    final duplicate = existing.any(
      (item) => item.id != categoryId && item.parentId == input.parentId,
    );
    if (duplicate) {
      throw const FormatException('同一層級已有相同名稱的類別');
    }
  }

  Future<Category> _getRequired(int id) async {
    final item = await (_database.select(
      _database.categories,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (item == null) throw StateError('找不到類別 $id');
    return _toDomain(item);
  }

  Category _toDomain(db.CategoryEntry item) => Category(
    id: item.id,
    parentId: item.parentId,
    name: item.name,
    type: CategoryType.values.byName(item.type),
    icon: item.icon,
    color: item.color,
    sortOrder: item.sortOrder,
    isActive: item.isActive,
    createdAt: item.createdAt.toUtc(),
    updatedAt: item.updatedAt.toUtc(),
  );
}
