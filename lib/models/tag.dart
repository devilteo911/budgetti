class Tag {
  final String id;
  final String userId;
  final String name;
  final int colorHex;

  Tag({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorHex,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? 'local',
      name: json['name'] as String,
      colorHex: json['color_hex'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'color_hex': colorHex,
    };
  }
}
