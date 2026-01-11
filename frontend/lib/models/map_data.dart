/// Map data models for driver home screen
class MapDataResponse {
  final bool success;
  final String timestamp;
  final int processingTimeMs;
  final WorkRegion currentWorkRegion;
  final List<NeighborRegion> neighborRegions;
  final List<NearbyStore> nearbyStores;
  final MapSummary summary;

  MapDataResponse({
    required this.success,
    required this.timestamp,
    required this.processingTimeMs,
    required this.currentWorkRegion,
    required this.neighborRegions,
    required this.nearbyStores,
    required this.summary,
  });

  factory MapDataResponse.fromJson(Map<String, dynamic> json) {
    return MapDataResponse(
      success: json['success'] ?? false,
      timestamp: json['timestamp'] ?? '',
      processingTimeMs: json['processing_time_ms'] ?? 0,
      currentWorkRegion: WorkRegion.fromJson(json['current_work_region'] ?? {}),
      neighborRegions: (json['neighbor_regions'] as List<dynamic>?)
              ?.map((e) => NeighborRegion.fromJson(e))
              .toList() ??
          [],
      nearbyStores: (json['nearby_stores'] as List<dynamic>?)
              ?.map((e) => NearbyStore.fromJson(e))
              .toList() ??
          [],
      summary: MapSummary.fromJson(json['summary'] ?? {}),
    );
  }
}

class WorkRegion {
  final String id;
  final String name;
  final int? level;
  final String? parentId;
  final String districtName;
  final String governorateId;
  final String governorateName;

  WorkRegion({
    required this.id,
    required this.name,
    this.level,
    this.parentId,
    required this.districtName,
    required this.governorateId,
    required this.governorateName,
  });

  factory WorkRegion.fromJson(Map<String, dynamic> json) {
    return WorkRegion(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      level: json['level'],
      parentId: json['parent_id'],
      districtName: json['district_name'] ?? '',
      governorateId: json['governorate_id'] ?? '',
      governorateName: json['governorate_name'] ?? '',
    );
  }
}

class NeighborRegion {
  final int priority;
  final String distanceKm;

  NeighborRegion({
    required this.priority,
    required this.distanceKm,
  });

  factory NeighborRegion.fromJson(Map<String, dynamic> json) {
    return NeighborRegion(
      priority: json['priority'] ?? 0,
      distanceKm: json['distance_km']?.toString() ?? '0',
    );
  }
}

class NearbyStore {
  final String storeId;
  final String name;
  final String category; // 'restaurant', 'store', 'cafe', etc.
  final double lat;
  final double lng;
  final String address;
  final String regionId;
  final double distanceKm;
  final bool isOpen; // مفتوح = ضمن ساعات العمل AND acceptingOrders = true
  final bool acceptingOrders; // يستقبل طلبات (من جدول Businesses)
  final bool isHot;
  final int hotScore;
  final String? photoUrl;
  final int expansionPriority; // 0 = Core, 1 = Extended, 2 = Far
  final String onlineStatus; // 'online', 'offline', 'busy'
  final bool isCoreRegion; // منطقة عمل أساسية
  final Map<String, dynamic>? workingHours;
  final int? waitingOrdersCount; // عدد الطلبات المنتظرة

  NearbyStore({
    required this.storeId,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.address,
    required this.regionId,
    required this.distanceKm,
    required this.isOpen,
    required this.acceptingOrders,
    required this.isHot,
    required this.hotScore,
    this.photoUrl,
    this.expansionPriority = 0,
    this.onlineStatus = 'online',
    this.isCoreRegion = true,
    this.workingHours,
    this.waitingOrdersCount,
  });

  factory NearbyStore.fromJson(Map<String, dynamic> json) {
    return NearbyStore(
      storeId: json['store_id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'restaurant',
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      address: json['address'] ?? '',
      regionId: json['region_id'] ?? '',
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      isOpen: json['is_open'] ?? false,
      acceptingOrders: json['accepting_orders'] ?? true, // ✅ حقل جديد
      isHot: json['is_hot'] ?? false,
      hotScore: json['hot_score'] ?? 0,
      expansionPriority: json['expansion_priority'] ?? 0,
      photoUrl: json['photo_url'],
      onlineStatus: json['online_status'] ?? 'online',
      isCoreRegion: json['is_core_region'] ?? (json['expansion_priority'] == 0),
      workingHours: json['working_hours'],
      waitingOrdersCount: json['waiting_orders_count'],
    );
  }
  
  /// تحديث حالة المطعم (لاستخدامها في real-time updates)
  NearbyStore copyWith({
    String? onlineStatus,
    bool? isOpen,
    bool? acceptingOrders,
    bool? isHot,
    int? hotScore,
    int? waitingOrdersCount,
  }) {
    return NearbyStore(
      storeId: storeId,
      name: name,
      category: category,
      lat: lat,
      lng: lng,
      address: address,
      regionId: regionId,
      distanceKm: distanceKm,
      isOpen: isOpen ?? this.isOpen,
      acceptingOrders: acceptingOrders ?? this.acceptingOrders,
      isHot: isHot ?? this.isHot,
      hotScore: hotScore ?? this.hotScore,
      photoUrl: photoUrl,
      expansionPriority: expansionPriority,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      isCoreRegion: isCoreRegion,
      workingHours: workingHours,
      waitingOrdersCount: waitingOrdersCount ?? this.waitingOrdersCount,
    );
  }
}

class MapSummary {
  final int totalStores;
  final int hotStores;
  final int openStores;
  final double regionCoverageKm;

  MapSummary({
    required this.totalStores,
    required this.hotStores,
    required this.openStores,
    required this.regionCoverageKm,
  });

  factory MapSummary.fromJson(Map<String, dynamic> json) {
    return MapSummary(
      totalStores: json['total_stores'] ?? 0,
      hotStores: json['hot_stores'] ?? 0,
      openStores: json['open_stores'] ?? 0,
      regionCoverageKm: (json['region_coverage_km'] ?? 0).toDouble(),
    );
  }
}
