class DriverProfile {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String city;
  final String vehicleType;
  final String licenseNumber;
  final String nationalId;
  final double rating;
  final int totalDeliveries;
  final DateTime joinDate;
  final String status;
  final VehicleInfo? vehicle;
  final bool isVerified;
  final String preferredLanguage;
  final EmergencyContact? emergencyContact;
  final String? profilePhoto;
  
  // Enhanced DynamoDB schema fields
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? dateOfBirth;
  final String? gender;
  final String? nationality;
  final String? address;
  final String? district;
  final String? postalCode;
  
  // License details
  final String? licenseExpiry;
  final String? licenseIssueDate;
  
  // Document references
  final String? drivingLicenseUrl;
  final String? drivingLicenseFileId;
  final String? drivingLicenseDocId;
  final String? drivingLicenseStatus;
  final String? vehicleRegistrationUrl;
  final String? vehicleRegistrationFileId;
  final String? vehicleRegistrationDocId;
  final String? vehicleRegistrationStatus;
  final String? nationalIdUrl;
  final String? nationalIdFileId;
  final String? nationalIdDocId;
  final String? nationalIdStatus;
  
  // Profile status flags
  final bool? profileComplete;
  final bool? documentsVerified;
  final bool? onboardingCompleted;
  final bool? termsAccepted;
  final bool? privacyPolicyAccepted;
  
  // Availability
  final String? availabilityStatus;
  final bool? isOnline;
  final bool? canReceiveOrders;
  
  // Statistics
  final int? totalTrips;
  final double? totalEarnings;
  final double? completionRate;
  
  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? profileCompletedAt;
  final DateTime? documentsVerifiedAt;
  
  // Metadata
  final String? registrationSource;

  DriverProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.city,
    required this.vehicleType,
    required this.licenseNumber,
    required this.nationalId,
    required this.rating,
    required this.totalDeliveries,
    required this.joinDate,
    required this.status,
    this.vehicle,
    required this.isVerified,
    required this.preferredLanguage,
    this.emergencyContact,
    this.profilePhoto,
    this.firstName,
    this.lastName,
    this.fullName,
    this.dateOfBirth,
    this.gender,
    this.nationality,
    this.address,
    this.district,
    this.postalCode,
    this.licenseExpiry,
    this.licenseIssueDate,
    this.drivingLicenseUrl,
    this.drivingLicenseFileId,
    this.drivingLicenseDocId,
    this.drivingLicenseStatus,
    this.vehicleRegistrationUrl,
    this.vehicleRegistrationFileId,
    this.vehicleRegistrationDocId,
    this.vehicleRegistrationStatus,
    this.nationalIdUrl,
    this.nationalIdFileId,
    this.nationalIdDocId,
    this.nationalIdStatus,
    this.profileComplete,
    this.documentsVerified,
    this.onboardingCompleted,
    this.termsAccepted,
    this.privacyPolicyAccepted,
    this.availabilityStatus,
    this.isOnline,
    this.canReceiveOrders,
    this.totalTrips,
    this.totalEarnings,
    this.completionRate,
    this.createdAt,
    this.updatedAt,
    this.profileCompletedAt,
    this.documentsVerifiedAt,
    this.registrationSource,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'] ?? json['driverId'] ?? '',
      name: json['name'] ?? json['fullName'] ?? '',
      phone: json['phone'] ?? json['phoneNumber'] ?? '',
      email: json['email'] ?? '',
      city: json['city'] ?? '',
      vehicleType:
          json['vehicle_type'] ??
          json['vehicleType'] ??
          (json['vehicleInfo'] != null
              ? json['vehicleInfo']['type'] ?? ''
              : ''),
      licenseNumber: json['license_number'] ?? json['licenseNumber'] ?? '',
      nationalId: json['national_id'] ?? json['nationalId'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      totalDeliveries:
          json['total_deliveries'] ??
          json['totalDeliveries'] ??
          json['totalTrips'] ??
          0,
      joinDate: _parseDateTime(
        json['join_date'] ?? json['joinDate'] ?? json['createdAt'],
      ),
      status: json['status'] ?? 'active',
      vehicle: _parseVehicleInfo(json),
      isVerified:
          json['is_verified'] ??
          json['isVerified'] ??
          json['documentsVerified'] ??
          false,
      preferredLanguage: json['preferred_language'] ?? 'ar',
      emergencyContact: json['emergency_contact'] != null
          ? EmergencyContact.fromJson(json['emergency_contact'])
          : null,
      profilePhoto: json['profile_photo'] ?? json['profilePhoto'],
      // Enhanced DynamoDB fields
      firstName: json['firstName'],
      lastName: json['lastName'],
      fullName: json['fullName'],
      dateOfBirth: json['dateOfBirth'],
      gender: json['gender'],
      nationality: json['nationality'],
      address: json['address'],
      district: json['district'],
      postalCode: json['postalCode'],
      licenseExpiry: json['licenseExpiry'],
      licenseIssueDate: json['licenseIssueDate'],
      drivingLicenseUrl: json['drivingLicenseUrl'],
      drivingLicenseFileId: json['drivingLicenseFileId'],
      drivingLicenseDocId: json['drivingLicenseDocId'],
      drivingLicenseStatus: json['drivingLicenseStatus'],
      vehicleRegistrationUrl: json['vehicleRegistrationUrl'],
      vehicleRegistrationFileId: json['vehicleRegistrationFileId'],
      vehicleRegistrationDocId: json['vehicleRegistrationDocId'],
      vehicleRegistrationStatus: json['vehicleRegistrationStatus'],
      nationalIdUrl: json['nationalIdUrl'],
      nationalIdFileId: json['nationalIdFileId'],
      nationalIdDocId: json['nationalIdDocId'],
      nationalIdStatus: json['nationalIdStatus'],
      profileComplete: json['profileComplete'],
      documentsVerified: json['documentsVerified'],
      onboardingCompleted: json['onboardingCompleted'],
      termsAccepted: json['termsAccepted'],
      privacyPolicyAccepted: json['privacyPolicyAccepted'],
      availabilityStatus: json['availabilityStatus'],
      isOnline: json['isOnline'],
      canReceiveOrders: json['canReceiveOrders'],
      totalTrips: json['totalTrips'],
      totalEarnings: _parseDouble(json['totalEarnings']),
      completionRate: _parseDouble(json['completionRate']),
      createdAt: _parseDateTimeNullable(json['createdAt']),
      updatedAt: _parseDateTimeNullable(json['updatedAt']),
      profileCompletedAt: _parseDateTimeNullable(json['profileCompletedAt']),
      documentsVerifiedAt: _parseDateTimeNullable(json['documentsVerifiedAt']),
      registrationSource: json['registrationSource'],
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  static DateTime? _parseDateTimeNullable(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    try {
      return double.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  static VehicleInfo? _parseVehicleInfo(Map<String, dynamic> json) {
    if (json['vehicle'] != null) {
      return VehicleInfo.fromJson(json['vehicle']);
    }
    if (json['vehicleInfo'] != null) {
      return VehicleInfo.fromJson(json['vehicleInfo']);
    }
    // Build vehicle info from individual fields if available
    if (json['vehicleMake'] != null || json['vehicleModel'] != null) {
      return VehicleInfo(
        make: json['vehicleMake'] ?? '',
        model: json['vehicleModel'] ?? '',
        year: int.tryParse(json['vehicleYear']?.toString() ?? '0') ?? 0,
        licensePlate: json['vehiclePlateNumber'] ?? '',
        color: json['vehicleColor'] ?? '',
        type: json['vehicleType'] ?? '',
        hasInsurance: true,
        capacity: json['vehicleCapacity'],
      );
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverId': id,
      'name': name,
      'fullName': fullName ?? name,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'phoneNumber': phone,
      'email': email,
      'city': city,
      'district': district,
      'address': address,
      'postalCode': postalCode,
      'vehicle_type': vehicleType,
      'vehicleType': vehicleType,
      'license_number': licenseNumber,
      'licenseNumber': licenseNumber,
      'licenseExpiry': licenseExpiry,
      'licenseIssueDate': licenseIssueDate,
      'national_id': nationalId,
      'nationalId': nationalId,
      'rating': rating,
      'total_deliveries': totalDeliveries,
      'totalTrips': totalTrips ?? totalDeliveries,
      'totalEarnings': totalEarnings,
      'completionRate': completionRate,
      'join_date': joinDate.toIso8601String(),
      'createdAt': createdAt?.toIso8601String() ?? joinDate.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'status': status,
      'vehicle': vehicle?.toJson(),
      'is_verified': isVerified,
      'isVerified': isVerified,
      'documentsVerified': documentsVerified ?? isVerified,
      'profileComplete': profileComplete,
      'onboardingCompleted': onboardingCompleted,
      'preferred_language': preferredLanguage,
      'emergency_contact': emergencyContact?.toJson(),
      'profile_photo': profilePhoto,
      'profilePhoto': profilePhoto,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'nationality': nationality,
      'drivingLicenseUrl': drivingLicenseUrl,
      'drivingLicenseFileId': drivingLicenseFileId,
      'drivingLicenseDocId': drivingLicenseDocId,
      'drivingLicenseStatus': drivingLicenseStatus,
      'vehicleRegistrationUrl': vehicleRegistrationUrl,
      'vehicleRegistrationFileId': vehicleRegistrationFileId,
      'vehicleRegistrationDocId': vehicleRegistrationDocId,
      'vehicleRegistrationStatus': vehicleRegistrationStatus,
      'nationalIdUrl': nationalIdUrl,
      'nationalIdFileId': nationalIdFileId,
      'nationalIdDocId': nationalIdDocId,
      'nationalIdStatus': nationalIdStatus,
      'availabilityStatus': availabilityStatus,
      'isOnline': isOnline,
      'canReceiveOrders': canReceiveOrders,
      'termsAccepted': termsAccepted,
      'privacyPolicyAccepted': privacyPolicyAccepted,
      'registrationSource': registrationSource,
      'profileCompletedAt': profileCompletedAt?.toIso8601String(),
      'documentsVerifiedAt': documentsVerifiedAt?.toIso8601String(),
    };
  }

  DriverProfile copyWith({
    String? name,
    String? phone,
    String? email,
    String? city,
    String? vehicleType,
    String? licenseNumber,
    String? nationalId,
    double? rating,
    int? totalDeliveries,
    DateTime? joinDate,
    String? status,
    VehicleInfo? vehicle,
    bool? isVerified,
    String? preferredLanguage,
    EmergencyContact? emergencyContact,
    String? profilePhoto,
    String? firstName,
    String? lastName,
    String? fullName,
    String? dateOfBirth,
    String? gender,
    String? nationality,
    String? address,
    String? district,
    String? postalCode,
    String? licenseExpiry,
    String? licenseIssueDate,
    String? drivingLicenseUrl,
    String? drivingLicenseFileId,
    String? drivingLicenseDocId,
    String? drivingLicenseStatus,
    String? vehicleRegistrationUrl,
    String? vehicleRegistrationFileId,
    String? vehicleRegistrationDocId,
    String? vehicleRegistrationStatus,
    String? nationalIdUrl,
    String? nationalIdFileId,
    String? nationalIdDocId,
    String? nationalIdStatus,
    bool? profileComplete,
    bool? documentsVerified,
    bool? onboardingCompleted,
    bool? termsAccepted,
    bool? privacyPolicyAccepted,
    String? availabilityStatus,
    bool? isOnline,
    bool? canReceiveOrders,
    int? totalTrips,
    double? totalEarnings,
    double? completionRate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? profileCompletedAt,
    DateTime? documentsVerifiedAt,
    String? registrationSource,
  }) {
    return DriverProfile(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      city: city ?? this.city,
      vehicleType: vehicleType ?? this.vehicleType,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      nationalId: nationalId ?? this.nationalId,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      joinDate: joinDate ?? this.joinDate,
      status: status ?? this.status,
      vehicle: vehicle ?? this.vehicle,
      isVerified: isVerified ?? this.isVerified,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      nationality: nationality ?? this.nationality,
      address: address ?? this.address,
      district: district ?? this.district,
      postalCode: postalCode ?? this.postalCode,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      licenseIssueDate: licenseIssueDate ?? this.licenseIssueDate,
      drivingLicenseUrl: drivingLicenseUrl ?? this.drivingLicenseUrl,
      drivingLicenseFileId: drivingLicenseFileId ?? this.drivingLicenseFileId,
      drivingLicenseDocId: drivingLicenseDocId ?? this.drivingLicenseDocId,
      drivingLicenseStatus: drivingLicenseStatus ?? this.drivingLicenseStatus,
      vehicleRegistrationUrl:
          vehicleRegistrationUrl ?? this.vehicleRegistrationUrl,
      vehicleRegistrationFileId:
          vehicleRegistrationFileId ?? this.vehicleRegistrationFileId,
      vehicleRegistrationDocId:
          vehicleRegistrationDocId ?? this.vehicleRegistrationDocId,
      vehicleRegistrationStatus:
          vehicleRegistrationStatus ?? this.vehicleRegistrationStatus,
      nationalIdUrl: nationalIdUrl ?? this.nationalIdUrl,
      nationalIdFileId: nationalIdFileId ?? this.nationalIdFileId,
      nationalIdDocId: nationalIdDocId ?? this.nationalIdDocId,
      nationalIdStatus: nationalIdStatus ?? this.nationalIdStatus,
      profileComplete: profileComplete ?? this.profileComplete,
      documentsVerified: documentsVerified ?? this.documentsVerified,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      privacyPolicyAccepted:
          privacyPolicyAccepted ?? this.privacyPolicyAccepted,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      isOnline: isOnline ?? this.isOnline,
      canReceiveOrders: canReceiveOrders ?? this.canReceiveOrders,
      totalTrips: totalTrips ?? this.totalTrips,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      completionRate: completionRate ?? this.completionRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profileCompletedAt: profileCompletedAt ?? this.profileCompletedAt,
      documentsVerifiedAt: documentsVerifiedAt ?? this.documentsVerifiedAt,
      registrationSource: registrationSource ?? this.registrationSource,
    );
  }
}

class VehicleInfo {
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final String color;
  final String type; // motorcycle, car, bicycle
  final bool hasInsurance;
  final DateTime? insuranceExpiry;
  final int? capacity;

  VehicleInfo({
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    required this.color,
    required this.type,
    required this.hasInsurance,
    this.insuranceExpiry,
    this.capacity,
  });

  factory VehicleInfo.fromJson(Map<String, dynamic> json) {
    return VehicleInfo(
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      year: json['year'] ?? 0,
      licensePlate: json['license_plate'] ?? json['plateNumber'] ?? '',
      color: json['color'] ?? '',
      type: json['type'] ?? '',
      hasInsurance: json['has_insurance'] ?? true,
      insuranceExpiry: json['insurance_expiry'] != null
          ? DateTime.parse(json['insurance_expiry'])
          : null,
      capacity: json['capacity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'make': make,
      'model': model,
      'year': year,
      'license_plate': licensePlate,
      'color': color,
      'type': type,
      'has_insurance': hasInsurance,
      'insurance_expiry': insuranceExpiry?.toIso8601String(),
      'capacity': capacity,
    };
  }
}

class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      relationship: json['relationship'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'phone': phone, 'relationship': relationship};
  }
}
