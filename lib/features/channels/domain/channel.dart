class ShoppingChannel {
  const ShoppingChannel({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
  });

  final int id;
  final String code;
  final String name;
  final bool isActive;
}
