/// Short-lived, account-scoped prefetch. Never persists percentages on-device.
class OfferPerformancePrefetch {
  final Future<Map<String, dynamic>?> Function() load;
  final DateTime Function() now;
  final Future<void> Function() pause;
  final Duration maxAge;
  OfferPerformancePrefetch(
      {required this.load,
      DateTime Function()? now,
      Future<void> Function()? pause,
      this.maxAge = const Duration(seconds: 5)})
      : now = now ?? DateTime.now,
        pause = pause ??
            (() => Future<void>.delayed(const Duration(milliseconds: 400)));
  String? _owner;
  int _generation = 0;
  Map<String, dynamic>? _data;
  DateTime? _loadedAt;
  Future<Map<String, dynamic>?>? _pending;
  void clear() {
    _generation++;
    _owner = null;
    _data = null;
    _loadedAt = null;
    _pending = null;
  }

  bool get _fresh {
    final projection = _data?['projection'];
    if (_loadedAt == null ||
        now().difference(_loadedAt!) >= maxAge ||
        projection is! Map ||
        projection['status'] != 'CURRENT') return false;
    final until = DateTime.tryParse('${projection['validUntil']}');
    return until != null && until.isAfter(now());
  }

  Future<void> prefetch(String owner) async {
    await read(owner);
  }

  Future<Map<String, dynamic>?> read(String owner) {
    if (_owner != owner) {
      clear();
      _owner = owner;
    }
    if (_fresh) return Future.value(_data);
    return _pending ??= _fetch(_generation);
  }

  Future<Map<String, dynamic>?> _fetch(int generation) async {
    Map<String, dynamic>? result;
    try {
      for (var i = 0; i < 3; i++) {
        try {
          result = await load().timeout(const Duration(seconds: 3));
        } catch (_) {
          result = null;
        }
        if (generation != _generation) return null;
        if (result?['projection'] is Map &&
            result!['projection']['status'] == 'CURRENT') break;
        if (i < 2) await pause();
      }
      if (generation != _generation) return null;
      _data = result;
      _loadedAt = now();
      return result;
    } finally {
      if (generation == _generation) _pending = null;
    }
  }
}
