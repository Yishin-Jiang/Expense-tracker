import 'category.dart';

abstract interface class CategoryRepository {
  Stream<List<Category>> watchActiveCategories(CategoryType type);
  Future<Category> createCategory(CategoryInput input);
  Future<Category> updateCategory(int id, CategoryInput input);
  Future<void> archiveCategory(int id);
}
