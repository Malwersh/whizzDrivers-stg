/// Driver Registration Models
/// Contains all data models for driver registration flow
library;

/// Result of driver registration API call
class DriverRegistrationResult {
  final bool success;
  final String? driverId;
  final String? cognitoUsername;
  final String? email;
  final String? phone;
  final String? verificationMethod;
  final String? verificationMessage;
  final String? message;
  final String? error;
  final String? errorCode;

  DriverRegistrationResult({
    required this.success,
    this.driverId,
    this.cognitoUsername,
    this.email,
    this.phone,
    this.verificationMethod,
    this.verificationMessage,
    this.message,
    this.error,
    this.errorCode,
  });

  factory DriverRegistrationResult.fromJson(Map<String, dynamic> json) {
    return DriverRegistrationResult(
      success: json['success'] ?? false,
      driverId: json['data']?['driverId'],
      cognitoUsername: json['data']?['cognitoUsername'],
      email: json['data']?['email'],
      phone: json['data']?['phone'],
      verificationMethod: json['data']?['verificationMethod'],
      verificationMessage: json['data']?['verificationMessage'],
      message: json['message'],
      error: json['error'],
      errorCode: json['errorCode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'driverId': driverId,
      'cognitoUsername': cognitoUsername,
      'email': email,
      'phone': phone,
      'verificationMethod': verificationMethod,
      'verificationMessage': verificationMessage,
      'message': message,
      'error': error,
      'errorCode': errorCode,
    };
  }
}

/// Result of verification confirmation API call
class VerificationResult {
  final bool success;
  final String? username;
  final String? verificationType;
  final String? verifiedAt;
  final String? nextStep;
  final String? message;
  final String? error;
  final String? errorCode;

  VerificationResult({
    required this.success,
    this.username,
    this.verificationType,
    this.verifiedAt,
    this.nextStep,
    this.message,
    this.error,
    this.errorCode,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      success: json['success'] ?? false,
      username: json['data']?['username'],
      verificationType: json['data']?['verificationType'],
      verifiedAt: json['data']?['verifiedAt'],
      nextStep: json['data']?['nextStep'],
      message: json['message'],
      error: json['error'],
      errorCode: json['errorCode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'username': username,
      'verificationType': verificationType,
      'verifiedAt': verifiedAt,
      'nextStep': nextStep,
      'message': message,
      'error': error,
      'errorCode': errorCode,
    };
  }
}

/// Result of resend verification API call
class ResendVerificationResult {
  final bool success;
  final String? message;
  final String? method;
  final String? error;
  final String? errorCode;

  ResendVerificationResult({
    required this.success,
    this.message,
    this.method,
    this.error,
    this.errorCode,
  });

  factory ResendVerificationResult.fromJson(Map<String, dynamic> json) {
    return ResendVerificationResult(
      success: json['success'] ?? false,
      message: json['message'],
      method: json['method'],
      error: json['error'],
      errorCode: json['errorCode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'method': method,
      'error': error,
      'errorCode': errorCode,
    };
  }
}

/// Validation result for registration data
class RegistrationValidation {
  final bool isValid;
  final List<String> errors;

  RegistrationValidation({required this.isValid, required this.errors});

  String get firstError => errors.isNotEmpty ? errors.first : '';
  String get allErrors => errors.join('\n');
}

/// Driver registration request data
class DriverRegistrationRequest {
  final String email;
  final String phone;
  final String password;
  final String firstName;
  final String lastName;
  final String vehicleType;
  final String vehiclePlate;
  final String nationalId;
  final String city;
  final String? emergencyContact;
  final String preferredVerification;

  DriverRegistrationRequest({
    required this.email,
    required this.phone,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.vehicleType,
    required this.vehiclePlate,
    required this.nationalId,
    required this.city,
    this.emergencyContact,
    this.preferredVerification = 'auto',
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'vehicleType': vehicleType,
      'vehiclePlate': vehiclePlate.trim(),
      'nationalId': nationalId.trim(),
      'city': city.trim(),
      'emergencyContact': emergencyContact?.trim(),
      'preferredVerification': preferredVerification,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// Driver profile data stored in DynamoDB
class DriverProfile {
  final String driverId;
  final String cognitoUsername;
  final String email;
  final String phone;
  final String firstName;
  final String lastName;
  final VehicleInfo vehicleInfo;
  final PersonalInfo personalInfo;
  final String registrationDate;
  final String status;
  final VerificationStatus verificationStatus;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  DriverProfile({
    required this.driverId,
    required this.cognitoUsername,
    required this.email,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.vehicleInfo,
    required this.personalInfo,
    required this.registrationDate,
    required this.status,
    required this.verificationStatus,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      driverId: json['driverId'],
      cognitoUsername: json['cognitoUsername'],
      email: json['email'],
      phone: json['phone'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      vehicleInfo: VehicleInfo.fromJson(json['vehicleInfo']),
      personalInfo: PersonalInfo.fromJson(json['personalInfo']),
      registrationDate: json['registrationDate'],
      status: json['status'],
      verificationStatus: VerificationStatus.fromJson(
        json['verificationStatus'],
      ),
      isActive: json['isActive'] ?? false,
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driverId': driverId,
      'cognitoUsername': cognitoUsername,
      'email': email,
      'phone': phone,
      'firstName': firstName,
      'lastName': lastName,
      'vehicleInfo': vehicleInfo.toJson(),
      'personalInfo': personalInfo.toJson(),
      'registrationDate': registrationDate,
      'status': status,
      'verificationStatus': verificationStatus.toJson(),
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

/// Vehicle information
class VehicleInfo {
  final String type;
  final String plateNumber;

  VehicleInfo({required this.type, required this.plateNumber});

  factory VehicleInfo.fromJson(Map<String, dynamic> json) {
    return VehicleInfo(type: json['type'], plateNumber: json['plateNumber']);
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'plateNumber': plateNumber};
  }
}

/// Personal information
class PersonalInfo {
  final String nationalId;
  final String city;
  final String? emergencyContact;

  PersonalInfo({
    required this.nationalId,
    required this.city,
    this.emergencyContact,
  });

  factory PersonalInfo.fromJson(Map<String, dynamic> json) {
    return PersonalInfo(
      nationalId: json['nationalId'],
      city: json['city'],
      emergencyContact: json['emergencyContact'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nationalId': nationalId,
      'city': city,
      'emergencyContact': emergencyContact,
    };
  }
}

/// Verification status
class VerificationStatus {
  final bool email;
  final bool phone;
  final bool documents;

  VerificationStatus({
    required this.email,
    required this.phone,
    required this.documents,
  });

  factory VerificationStatus.fromJson(Map<String, dynamic> json) {
    return VerificationStatus(
      email: json['email'] ?? false,
      phone: json['phone'] ?? false,
      documents: json['documents'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'email': email, 'phone': phone, 'documents': documents};
  }

  bool get isFullyVerified => email && phone && documents;
  bool get hasAnyVerification => email || phone || documents;
}
