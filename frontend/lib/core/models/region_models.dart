class Country {
  final String regionId;
  final String name;
  final String nameAr;
  final int level;

  Country({
    required this.regionId,
    required this.name,
    required this.nameAr,
    required this.level,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      regionId: json['regionId'] as String,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String,
      level: json['level'] as int,
    );
  }

  String get displayName => nameAr;
}

class Governorate {
  final String regionId;
  final String name;
  final String nameAr;
  final int level;
  final String parentId;

  Governorate({
    required this.regionId,
    required this.name,
    required this.nameAr,
    required this.level,
    required this.parentId,
  });

  factory Governorate.fromJson(Map<String, dynamic> json) {
    return Governorate(
      regionId: json['regionId'] as String,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String,
      level: json['level'] as int,
      parentId: json['parent_id'] as String,
    );
  }

  String get displayName => nameAr;
}

class ResidentialArea {
  final String regionId;
  final String name;
  final String nameAr;
  final int level;
  final String parentId;
  final String? parentDistrictName;

  ResidentialArea({
    required this.regionId,
    required this.name,
    required this.nameAr,
    required this.level,
    required this.parentId,
    this.parentDistrictName,
  });

  factory ResidentialArea.fromJson(Map<String, dynamic> json) {
    return ResidentialArea(
      regionId: json['regionId'] as String,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String,
      level: json['level'] as int,
      parentId: json['parent_id'] as String,
      parentDistrictName: json['parentDistrictName'] as String?,
    );
  }

  String get displayName {
    if (parentDistrictName != null) {
      return '$nameAr ($parentDistrictName)';
    }
    return nameAr;
  }
}
