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

class ShoppingChannelInput {
  const ShoppingChannelInput({required this.name});

  final String name;

  void validate() {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const FormatException('請輸入購物管道名稱');
    }
    if (normalized.length > 40) {
      throw const FormatException('購物管道名稱最多 40 個字');
    }
  }
}
