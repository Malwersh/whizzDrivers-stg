enum MapDataFailureKind { outsideCoverage, authentication, connection, server }

class MapDataFailure implements Exception {
  const MapDataFailure(this.kind);
  final MapDataFailureKind kind;

  static MapDataFailure? fromResponse(int status, Map<String, dynamic> body) {
    if (status == 401) {
      return const MapDataFailure(MapDataFailureKind.authentication);
    }
    if (status == 404 &&
        (body['error'] == 'Region not found for coordinates' ||
            body['code'] == 'OUTSIDE_SERVICE_AREA' ||
            body['code'] == 'REGION_NOT_FOUND')) {
      return const MapDataFailure(MapDataFailureKind.outsideCoverage);
    }
    if (status != 200) return const MapDataFailure(MapDataFailureKind.server);
    return null;
  }

  @override
  String toString() => switch (kind) {
        MapDataFailureKind.outsideCoverage => 'موقعك الحالي خارج مناطق الخدمة',
        MapDataFailureKind.authentication =>
          'تعذّر التحقق من الجلسة لهذه الخدمة. أعد المحاولة.',
        MapDataFailureKind.connection =>
          'تعذر الاتصال بالخدمة. تحقق من الإنترنت وأعد المحاولة.',
        MapDataFailureKind.server =>
          'تعذر تحميل المتاجر حاليًا. حاول مرة أخرى.',
      };
}
