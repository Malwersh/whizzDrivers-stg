class DeliveryEquipment {
  final String id;
  final String name;
  final String type; // thermal_bag, phone_holder, charger, helmet, etc.
  final String status; // owned, rented, needed
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final double? purchasePrice;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final bool isRequired;
  final String? notes;
  final String? imageUrl;

  DeliveryEquipment({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.purchaseDate,
    this.expiryDate,
    this.purchasePrice,
    this.brand,
    this.model,
    this.serialNumber,
    required this.isRequired,
    this.notes,
    this.imageUrl,
  });

  factory DeliveryEquipment.fromJson(Map<String, dynamic> json) {
    return DeliveryEquipment(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? 'needed',
      purchaseDate: json['purchase_date'] != null
          ? DateTime.parse(json['purchase_date'])
          : null,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'])
          : null,
      purchasePrice: json['purchase_price']?.toDouble(),
      brand: json['brand'],
      model: json['model'],
      serialNumber: json['serial_number'],
      isRequired: json['is_required'] ?? false,
      notes: json['notes'],
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'status': status,
      'purchase_date': purchaseDate?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'purchase_price': purchasePrice,
      'brand': brand,
      'model': model,
      'serial_number': serialNumber,
      'is_required': isRequired,
      'notes': notes,
      'image_url': imageUrl,
    };
  }

  DeliveryEquipment copyWith({
    String? id,
    String? name,
    String? type,
    String? status,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    double? purchasePrice,
    String? brand,
    String? model,
    String? serialNumber,
    bool? isRequired,
    String? notes,
    String? imageUrl,
  }) {
    return DeliveryEquipment(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      isRequired: isRequired ?? this.isRequired,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class EquipmentType {
  final String id;
  final String name;
  final String nameArabic;
  final String description;
  final bool isRequired;
  final String iconName;
  final double? estimatedPrice;
  final List<String> recommendedBrands;

  EquipmentType({
    required this.id,
    required this.name,
    required this.nameArabic,
    required this.description,
    required this.isRequired,
    required this.iconName,
    this.estimatedPrice,
    required this.recommendedBrands,
  });

  factory EquipmentType.fromJson(Map<String, dynamic> json) {
    return EquipmentType(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nameArabic: json['name_arabic'] ?? '',
      description: json['description'] ?? '',
      isRequired: json['is_required'] ?? false,
      iconName: json['icon_name'] ?? 'category',
      estimatedPrice: json['estimated_price']?.toDouble(),
      recommendedBrands: List<String>.from(json['recommended_brands'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_arabic': nameArabic,
      'description': description,
      'is_required': isRequired,
      'icon_name': iconName,
      'estimated_price': estimatedPrice,
      'recommended_brands': recommendedBrands,
    };
  }
}
