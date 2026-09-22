// EP02 - US10: Xem/Tìm kiếm dịch vụ
class ServiceCategory {
  ServiceCategory({
    required this.id,
    required this.name,
    this.description,
    required this.basePrice,
    required this.unit,
    this.iconUrl,
  });

  final int id;
  final String name;
  final String? description;
  final double basePrice;
  final String unit;
  final String? iconUrl;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) => ServiceCategory(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        basePrice: (json['basePrice'] as num).toDouble(),
        unit: json['unit'] as String,
        iconUrl: json['iconUrl'] as String?,
      );
}
