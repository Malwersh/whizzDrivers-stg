// Profile Status Model
// Represents the completion status of a driver profile
// Version: 1.0
// Date: 2025-10-18

/// Enum representing profile status stages
enum ProfileStatusEnum {
  /// User just verified, needs to complete profile
  pendingProfile,

  /// User has basic profile, needs documents
  pendingDocs,

  /// User has uploaded documents, awaiting admin review
  pendingReview,

  /// Profile fully approved, user can access app
  active,

  /// Account suspended by admin
  suspended,

  /// Profile rejected (e.g., invalid documents)
  rejected,
}

/// Profile status response with completion details
class ProfileStatus {
  /// Whether the profile exists in the database
  final bool exists;

  /// Current profile status
  final ProfileStatusEnum status;

  /// Whether the profile is complete (has all required fields)
  final bool isComplete;

  /// List of missing required fields
  final List<String> missingFields;

  /// Whether user needs to be redirected to complete profile
  final bool needsRedirect;

  /// The path to redirect to (if needsRedirect is true)
  final String? redirectPath;

  /// The full profile data from DynamoDB (optional)
  final Map<String, dynamic>? profileData;

  /// Error message if profile check failed
  final String? error;

  ProfileStatus({
    required this.exists,
    required this.status,
    required this.isComplete,
    required this.missingFields,
    required this.needsRedirect,
    this.redirectPath,
    this.profileData,
    this.error,
  });

  /// Check if user can access the main app
  bool get canAccessMainApp => isComplete && status == ProfileStatusEnum.active;

  /// Get user-friendly status message
  String get statusMessage {
    switch (status) {
      case ProfileStatusEnum.pendingProfile:
        return 'يرجى إكمال معلومات الملف الشخصي';
      case ProfileStatusEnum.pendingDocs:
        return 'يرجى رفع المستندات المطلوبة';
      case ProfileStatusEnum.pendingReview:
        return 'ملفك قيد المراجعة';
      case ProfileStatusEnum.active:
        return 'حسابك نشط';
      case ProfileStatusEnum.suspended:
        return 'تم تعليق حسابك';
      case ProfileStatusEnum.rejected:
        return 'تم رفض طلبك';
    }
  }

  /// Get status color for UI
  String get statusColor {
    switch (status) {
      case ProfileStatusEnum.pendingProfile:
      case ProfileStatusEnum.pendingDocs:
        return 'orange';
      case ProfileStatusEnum.pendingReview:
        return 'blue';
      case ProfileStatusEnum.active:
        return 'green';
      case ProfileStatusEnum.suspended:
      case ProfileStatusEnum.rejected:
        return 'red';
    }
  }

  @override
  String toString() {
    return 'ProfileStatus(exists: $exists, status: $status, isComplete: $isComplete, '
        'missingFields: $missingFields, needsRedirect: $needsRedirect)';
  }

  /// Create from JSON (for API responses)
  factory ProfileStatus.fromJson(Map<String, dynamic> json) {
    return ProfileStatus(
      exists: json['profileExists'] ?? false,
      status: _parseStatus(json['status']),
      isComplete: json['isComplete'] ?? false,
      missingFields: List<String>.from(json['missingFields'] ?? []),
      needsRedirect: !(json['isComplete'] ?? false),
      redirectPath: (json['isComplete'] ?? false)
          ? null
          : '/driver-profile-setup',
      profileData: json['profileData'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'exists': exists,
      'status': _statusToString(status),
      'isComplete': isComplete,
      'missingFields': missingFields,
      'needsRedirect': needsRedirect,
      'redirectPath': redirectPath,
      'profileData': profileData,
      'error': error,
    };
  }

  /// Parse status string to enum
  static ProfileStatusEnum _parseStatus(dynamic status) {
    if (status == null) return ProfileStatusEnum.pendingProfile;

    final statusString = status.toString().toUpperCase();
    switch (statusString) {
      case 'PENDING_PROFILE':
        return ProfileStatusEnum.pendingProfile;
      case 'PENDING_DOCS':
        return ProfileStatusEnum.pendingDocs;
      case 'PENDING_REVIEW':
        return ProfileStatusEnum.pendingReview;
      case 'ACTIVE':
        return ProfileStatusEnum.active;
      case 'SUSPENDED':
        return ProfileStatusEnum.suspended;
      case 'REJECTED':
        return ProfileStatusEnum.rejected;
      default:
        return ProfileStatusEnum.pendingProfile;
    }
  }

  /// Convert enum to string
  static String _statusToString(ProfileStatusEnum status) {
    switch (status) {
      case ProfileStatusEnum.pendingProfile:
        return 'PENDING_PROFILE';
      case ProfileStatusEnum.pendingDocs:
        return 'PENDING_DOCS';
      case ProfileStatusEnum.pendingReview:
        return 'PENDING_REVIEW';
      case ProfileStatusEnum.active:
        return 'ACTIVE';
      case ProfileStatusEnum.suspended:
        return 'SUSPENDED';
      case ProfileStatusEnum.rejected:
        return 'REJECTED';
    }
  }
}
