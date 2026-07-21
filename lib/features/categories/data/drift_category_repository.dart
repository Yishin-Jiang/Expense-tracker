import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../domain/category.dart';
import '../domain/category_repository.dart';

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._database);
  final db.AppDatabase _database;

  @override
  Stream<List<Category>> watchActiveCategories(CategoryType type) {
    return _database.categoryDao
        .watchActiveCategories(type.name)
        .map((items) => items.map(_toDomain).toList(growable: false));
  }

  @override
  Future<Category> createCategory(CategoryInput input) async {
    input.validate();
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
    if (await _database.categoryDao.archiveCategory(id) != 1) {
      throw StateError('找不到類別 $id');
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
