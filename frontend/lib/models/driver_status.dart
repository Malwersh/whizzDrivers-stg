/// Driver availability status
enum DriverStatus {
  /// Driver is online and available for orders
  online,
  
  /// Driver is busy with an active order
  busy,
  
  /// Driver is on duty (ready to work)
  onDuty,
  
  /// Driver is offline and not receiving orders
  offline,
}

extension DriverStatusExtension on DriverStatus {
  /// Get Arabic display text
  String get displayText {
    switch (this) {
      case DriverStatus.online:
        return 'متاح';
      case DriverStatus.busy:
        return 'مشغول';
      case DriverStatus.onDuty:
        return 'في الخدمة';
      case DriverStatus.offline:
        return 'غير متاح';
    }
  }
  
  /// Get status color
  String get colorHex {
    switch (this) {
      case DriverStatus.online:
        return '#4CAF50'; // Green
      case DriverStatus.busy:
        return '#FF9800'; // Orange
      case DriverStatus.onDuty:
        return '#2196F3'; // Blue
      case DriverStatus.offline:
        return '#757575'; // Grey
    }
  }
  
  /// Parse from string
  static DriverStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return DriverStatus.online;
      case 'busy':
        return DriverStatus.busy;
      case 'offline':
      default:
        return DriverStatus.offline;
    }
  }
}
