import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

const categoryColors = <String>[
  '#C9E5D4',
  '#FAE0D9',
  '#F5D16E',
  '#DCE7F7',
  '#E8DDF4',
];

const categoryIcons = <String, IconData>{
  'restaurant': Icons.restaurant_outlined,
  'breakfast_dining': Icons.breakfast_dining_outlined,
  'lunch_dining': Icons.lunch_dining_outlined,
  'dinner_dining': Icons.dinner_dining_outlined,
  'shopping_basket': Icons.shopping_basket_outlined,
  'home': Icons.home_outlined,
  'directions_bus': Icons.directions_bus_outlined,
  'payments': Icons.payments_outlined,
  'school': Icons.school_outlined,
  'local_hospital': Icons.local_hospital_outlined,
  'sports_esports': Icons.sports_esports_outlined,
  'category': Icons.category_outlined,
};

IconData categoryIcon(String? name) =>
    categoryIcons[name] ?? Icons.category_outlined;

Color categoryColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
    return AppColors.primaryContainer;
  }
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}
