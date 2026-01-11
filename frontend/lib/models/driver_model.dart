// Driver model for the Wizz driver app

enum DriverStatus {
  offline,
  online,
  busy,
  onBreak,
}

enum VehicleType {
  motorcycle,
  car,
  bicycle,
  scooter,
}

class VehicleInfo {
  final VehicleType type;
  final String model;
  final String plateNumber;
  final String color;
  final int year;

  const VehicleInfo({
    required this.type,
    required this.model,
    required this.plateNumber,
    required this.color,
    required this.year,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'model': model,
      'plateNumber': plateNumber,
      'color': color,
      'year': year,
    };
  }

  factory VehicleInfo.fromJson(Map<String, dynamic> json) {
    return VehicleInfo(
      type: VehicleType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => VehicleType.motorcycle,
      ),
      model: json['model'] ?? '',
      plateNumber: json['plateNumber'] ?? '',
      color: json['color'] ?? '',
      year: json['year'] ?? 0,
    );
  }
}

class DriverLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final double? heading;
  final double? speed;

  const DriverLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.heading,
    this.speed,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
      'heading': heading,
      'speed': speed,
    };
  }

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    return DriverLocation(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
      accuracy: json['accuracy']?.toDouble(),
      heading: json['heading']?.toDouble(),
      speed: json['speed']?.toDouble(),
    );
  }
}

class DriverStats {
  final int totalDeliveries;
  final double totalEarnings;
  final double averageRating;
  final int totalRatings;
  final Duration totalOnlineTime;
  final int completedOrders;
  final int cancelledOrders;

  const DriverStats({
    required this.totalDeliveries,
    required this.totalEarnings,
    required this.averageRating,
    required this.totalRatings,
    required this.totalOnlineTime,
    required this.completedOrders,
    required this.cancelledOrders,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalDeliveries': totalDeliveries,
      'totalEarnings': totalEarnings,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'totalOnlineTimeMinutes': totalOnlineTime.inMinutes,
      'completedOrders': completedOrders,
      'cancelledOrders': cancelledOrders,
    };
  }

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    return DriverStats(
      totalDeliveries: json['totalDeliveries'] ?? 0,
      totalEarnings: json['totalEarnings']?.toDouble() ?? 0.0,
      averageRating: json['averageRating']?.toDouble() ?? 0.0,
      totalRatings: json['totalRatings'] ?? 0,
      totalOnlineTime: Duration(minutes: json['totalOnlineTimeMinutes'] ?? 0),
      completedOrders: json['completedOrders'] ?? 0,
      cancelledOrders: json['cancelledOrders'] ?? 0,
    );
  }
}

class DriverModel {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String? profileImageUrl;
  final VehicleInfo vehicleInfo;
  final DriverLocation? currentLocation;
  final DriverStatus status;
  final DriverStats stats;
  final String? fcmToken;
  final bool isVerified;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final String? currentOrderId;

  const DriverModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    this.profileImageUrl,
    required this.vehicleInfo,
    this.currentLocation,
    required this.status,
    required this.stats,
    this.fcmToken,
    required this.isVerified,
    required this.isActive,
    required this.createdAt,
    this.lastActiveAt,
    this.currentOrderId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'vehicleInfo': vehicleInfo.toJson(),
      'currentLocation': currentLocation?.toJson(),
      'status': status.name,
      'stats': stats.toJson(),
      'fcmToken': fcmToken,
      'isVerified': isVerified,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt?.toIso8601String(),
      'currentOrderId': currentOrderId,
    };
  }

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      vehicleInfo: VehicleInfo.fromJson(json['vehicleInfo'] ?? {}),
      currentLocation: json['currentLocation'] != null
          ? DriverLocation.fromJson(json['currentLocation'])
          : null,
      status: DriverStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DriverStatus.offline,
      ),
      stats: DriverStats.fromJson(json['stats'] ?? {}),
      fcmToken: json['fcmToken'],
      isVerified: json['isVerified'] ?? false,
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.parse(json['lastActiveAt'])
          : null,
      currentOrderId: json['currentOrderId'],
    );
  }

  DriverModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    VehicleInfo? vehicleInfo,
    DriverLocation? currentLocation,
    DriverStatus? status,
    DriverStats? stats,
    String? fcmToken,
    bool? isVerified,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    String? currentOrderId,
  }) {
    return DriverModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      vehicleInfo: vehicleInfo ?? this.vehicleInfo,
      currentLocation: currentLocation ?? this.currentLocation,
      status: status ?? this.status,
      stats: stats ?? this.stats,
      fcmToken: fcmToken ?? this.fcmToken,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      currentOrderId: currentOrderId ?? this.currentOrderId,
    );
  }

  // Helper getters
  String get displayName => name.isNotEmpty ? name : 'Driver';
  bool get isOnline => status != DriverStatus.offline;
  bool get canAcceptOrders => isOnline && isVerified && isActive && currentOrderId == null;
  String get statusDisplayName {
    switch (status) {
      case DriverStatus.offline:
        return 'غير متصل';
      case DriverStatus.online:
        return 'متصل';
      case DriverStatus.busy:
        return 'مشغول';
      case DriverStatus.onBreak:
        return 'في استراحة';
    }
  }

  String get vehicleDisplayName {
    switch (vehicleInfo.type) {
      case VehicleType.motorcycle:
        return 'دراجة نارية';
      case VehicleType.car:
        return 'سيارة';
      case VehicleType.bicycle:
        return 'دراجة هوائية';
      case VehicleType.scooter:
        return 'سكوتر';
    }
  }
}
