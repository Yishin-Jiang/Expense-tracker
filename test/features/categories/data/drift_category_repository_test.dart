import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/features/categories/data/drift_category_repository.dart';
import 'package:accounting_app/features/categories/domain/category.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftCategoryRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftCategoryRepository(database);
  });

  tearDown(() => database.close());

  test('creates, updates, archives, and restores a child category', () async {
    final defaults = await repository.watchAllCategories().first;
    final food = defaults.singleWhere((item) => item.name == '飲食');

    final created = await repository.createCategory(
      CategoryInput(
        name: '咖啡',
        type: CategoryType.expense,
        parentId: food.id,
        icon: 'restaurant',
        color: '#C9E5D4',
        sortOrder: 90,
      ),
    );
    expect(created.parentId, food.id);
    expect(created.isActive, isTrue);

    final updated = await repository.updateCategory(
      created.id,
      CategoryInput(
        name: '咖啡飲品',
        type: CategoryType.expense,
        parentId: food.id,
        icon: 'restaurant',
        color: '#F5D16E',
        sortOrder: 90,
      ),
    );
    expect(updated.name, '咖啡飲品');
    expect(updated.color, '#F5D16E');

    await repository.archiveCategory(created.id);
    expect((await repository.getCategory(created.id))?.isActive, isFalse);
    expect(
      await repository.watchActiveCategories(CategoryType.expense).first,
      isNot(contains(predicate<Category>((item) => item.id == created.id))),
    );

    await repository.restoreCategory(created.id);
    expect((await repository.getCategory(created.id))?.isActive, isTrue);
  });

  test('creates a root category without a parent', () async {
    final created = await repository.createCategory(
      const CategoryInput(
        name: '娛樂',
        type: CategoryType.expense,
        icon: 'sports_esports',
        color: '#E8DDF4',
        sortOrder: 90,
      ),
    );

    expect(created.name, '娛樂');
    expect(created.parentId, isNull);
    expect(created.isActive, isTrue);
  });

  test('rejects duplicate siblings and unsafe parent operations', () async {
    final defaults = await repository.watchAllCategories().first;
    final food = defaults.singleWhere((item) => item.name == '飲食');
    final breakfast = defaults.singleWhere((item) => item.name == '早餐');
    final housing = defaults.singleWhere((item) => item.name == '房租');

    expect(
      () => repository.createCategory(
        CategoryInput(
          name: '早餐',
          type: CategoryType.expense,
          parentId: food.id,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => repository.createCategory(
        CategoryInput(
          name: '蛋餅',
          type: CategoryType.expense,
          parentId: breakfast.id,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => repository.archiveCategory(food.id),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => repository.updateCategory(
        food.id,
        CategoryInput(
          name: food.name,
          type: food.type,
          parentId: housing.id,
          icon: food.icon,
          color: food.color,
          sortOrder: food.sortOrder,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
