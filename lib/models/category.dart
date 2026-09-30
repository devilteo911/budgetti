
class Category {
  final String id;
  final String userId;
  final String name;
  final int iconCode;
  final int colorHex;
  final String type; // 'income' or 'expense'
  final String? description;

  /// The stored palette slot (0–7), null until one is assigned. Expense only.
  final int? colorSlot;

  Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.iconCode,
    required this.colorHex,
    required this.type,
    this.description,
    this.colorSlot,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      iconCode: json['icon_code'],
      colorHex: json['color_hex'],
      type: json['type'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'icon_code': iconCode,
      'color_hex': colorHex,
      'type': type,
      'description': description,
    };
  }
}
