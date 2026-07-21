import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../data/drift_category_repository.dart';
import '../../domain/category.dart';
import '../../domain/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => DriftCategoryRepository(ref.watch(databaseProvider)),
);

final activeCategoriesProvider = StreamProvider.autoDispose
    .family<List<Category>, CategoryType>(
      (ref, type) =>
          ref.watch(categoryRepositoryProvider).watchActiveCategories(type),
    );

final categoryByIdProvider = FutureProvider.autoDispose.family<Category?, int>(
  (ref, id) => ref.watch(categoryRepositoryProvider).getCategory(id),
);
