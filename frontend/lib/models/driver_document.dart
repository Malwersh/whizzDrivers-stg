/// Driver Document Model
/// Represents a document uploaded by the driver (license, ID, vehicle registration, etc.)
class DriverDocument {
  final String? url;
  final String? fileId;
  final String? docId;
  final String? status; // pending, verified, rejected
  final String type; // drivingLicense, vehicleRegistration, nationalId

  DriverDocument({
    this.url,
    this.fileId,
    this.docId,
    this.status,
    required this.type,
  });

  bool get isVerified => status?.toLowerCase() == 'verified';
  bool get isPending => status?.toLowerCase() == 'pending';
  bool get isRejected => status?.toLowerCase() == 'rejected';
  bool get hasDocument => url != null && url!.isNotEmpty;

  factory DriverDocument.fromProfile(Map<String, dynamic> json, String type) {
    final prefix = _getFieldPrefix(type);
    return DriverDocument(
      url: json['${prefix}Url'],
      fileId: json['${prefix}FileId'],
      docId: json['${prefix}DocId'],
      status: json['${prefix}Status'],
      type: type,
    );
  }

  static String _getFieldPrefix(String type) {
    switch (type) {
      case 'drivingLicense':
        return 'drivingLicense';
      case 'vehicleRegistration':
        return 'vehicleRegistration';
      case 'nationalId':
        return 'nationalId';
      default:
        return type;
    }
  }

  String get displayName {
    switch (type) {
      case 'drivingLicense':
        return 'رخصة القيادة';
      case 'vehicleRegistration':
        return 'استمارة المركبة';
      case 'nationalId':
        return 'البطاقة الوطنية';
      default:
        return type;
    }
  }

  String get statusText {
    if (isVerified) return 'موثق';
    if (isPending) return 'قيد المراجعة';
    if (isRejected) return 'مرفوض';
    return 'غير مرفوع';
  }
}
