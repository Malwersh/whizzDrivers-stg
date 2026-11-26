/// Legacy rates without a declared sample/status are not verified percentages.
class DriverPerformanceSnapshot {
  final Map<String, dynamic> data;
  DriverPerformanceSnapshot(this.data);
  DateTime? get updatedAt => DateTime.tryParse('${data['updatedAt'] ?? ''}');
  double? rate(String name) {
    final value = data[name];
    if (updatedAt == null ||
        !['AVAILABLE', 'PROVISIONAL'].contains(data['${name}Status']) ||
        value is! num ||
        !value.isFinite ||
        value < 0 ||
        value > 1) {
      return null;
    }
    return value.toDouble();
  }

  double? get customerRating {
    final average = data['customerRating'], count = data['customerRatingCount'];
    if (data['rulesVersion'] == 'OBSERVED_DRIVER_PERFORMANCE_V4') {
      final window = data['ratingWindow'];
      if (window is! Map ||
          window['basis'] != 'LAST_100_VALID_CUSTOMER_RATINGS_V1' ||
          !['AVAILABLE', 'PROVISIONAL'].contains(window['status']) ||
          window['average'] != average ||
          window['count'] != count ||
          count is! int ||
          count > 100) return null;
    }
    return average is num &&
            average.isFinite &&
            average >= 1 &&
            average <= 5 &&
            count is int &&
            count > 0
        ? average.toDouble()
        : null;
  }

  int get customerRatingCount =>
      customerRating == null ? 0 : data['customerRatingCount'] as int;

  int? count(String name) {
    final value = data[name];
    if (updatedAt == null || value is! int || value < 0) return null;
    return value;
  }
}
