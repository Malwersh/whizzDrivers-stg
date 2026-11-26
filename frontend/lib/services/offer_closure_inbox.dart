import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A closure only invalidates an offer. It never creates an assignment or moves money.
class OfferClosure {
  const OfferClosure(
      {required this.driverId,
      required this.offerId,
      required this.orderId,
      required this.eventId,
      required this.receivedAt,
      this.cycleId});
  final String driverId, offerId, orderId, eventId;
  final String? cycleId;
  final DateTime receivedAt;

  bool matches(
          {required String offerId,
          required String orderId,
          String? cycleId}) =>
      this.offerId == offerId &&
      this.orderId == orderId &&
      (this.cycleId == null || cycleId == null || this.cycleId == cycleId);

  Map<String, dynamic> toJson() => {
        'driverId': driverId,
        'offerId': offerId,
        'orderId': orderId,
        'eventId': eventId,
        'cycleId': cycleId,
        'receivedAt': receivedAt.toUtc().toIso8601String()
      };
}

/// Existing device preferences, one key per owner/offer/cycle: background writes
/// of different closures cannot overwrite a shared JSON list. Reload before reads
/// because Firebase's background isolate has a separate preferences cache.
class OfferClosureInbox {
  static const prefix = 'dispatchOfferClosure.v1.';
  static const retention = Duration(hours: 24);
  static final _events = StreamController<OfferClosure>.broadcast();
  static Stream<OfferClosure> get events => _events.stream;
  static bool _id(dynamic v) =>
      v is String &&
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9_:#.\-]{0,149}$').hasMatch(v);
  static bool isClosure(Map<String, dynamic> data) =>
      const [
        'offer_taken',
        'offer_accepted_by_other',
        'offer_no_longer_available',
        'dispatch_offer_closed'
      ].contains(data['type']) ||
      data['action'] == 'remove_offer';
  static String _part(String value) => base64Url.encode(utf8.encode(value));
  static String _ownerPrefix(String owner) => '$prefix${_part(owner)}.';

  static Future<OfferClosure?> record(Map<String, dynamic> data,
      {String? socketDriverId, DateTime? now}) async {
    if (!isClosure(data)) return null;
    final driver = data['driverId'] ?? data['driver_id'] ?? socketDriverId;
    final offer = data['offerId'] ?? data['offer_id'];
    final order = data['orderId'] ?? data['order_id'];
    final cycle = data['cycleId'] ?? data['dispatchCycleId'];
    if (!_id(driver) ||
        !_id(offer) ||
        !_id(order) ||
        (cycle != null && !_id(cycle)) ||
        (socketDriverId != null && driver != socketDriverId)) {
      return null;
    }
    final event =
        data['eventId'] ?? (socketDriverId != null ? 'socket:$offer' : null);
    if (!_id(event)) return null;
    final at = (now ?? DateTime.now()).toUtc();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key =
        '${_ownerPrefix(driver)}${_part(offer)}.${_part(order)}.${_part(cycle ?? '')}';
    final prior = _decode(prefs.getString(key), at);
    if (prior != null) return prior;
    final closure = OfferClosure(
        driverId: driver,
        offerId: offer,
        orderId: order,
        cycleId: cycle,
        eventId: event,
        receivedAt: at);
    if (!await prefs.setString(key, jsonEncode(closure.toJson()))) {
      throw StateError('OFFER_CLOSURE_NOT_SAVED');
    }
    _events.add(closure);
    return closure;
  }

  static OfferClosure? _decode(String? raw, DateTime now) {
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse(v['receivedAt'] as String);
      if (!['driverId', 'offerId', 'orderId', 'eventId']
              .every((k) => _id(v[k])) ||
          (v['cycleId'] != null && !_id(v['cycleId'])) ||
          at == null ||
          !at.add(retention).isAfter(now)) {
        return null;
      }
      return OfferClosure(
          driverId: v['driverId'],
          offerId: v['offerId'],
          orderId: v['orderId'],
          eventId: v['eventId'],
          cycleId: v['cycleId'],
          receivedAt: at);
    } catch (_) {
      return null;
    }
  }

  static Future<List<OfferClosure>> read(String driverId,
      {DateTime? now}) async {
    if (!_id(driverId)) return const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final at = (now ?? DateTime.now()).toUtc(), records = <OfferClosure>[];
    for (final key
        in prefs.getKeys().where((k) => k.startsWith(_ownerPrefix(driverId)))) {
      final closure = _decode(prefs.getString(key), at);
      if (closure == null) {
        await prefs.remove(key);
        continue;
      }
      if (closure.driverId == driverId) records.add(closure);
    }
    return records;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    for (final key in prefs.getKeys().where((k) => k.startsWith(prefix))) {
      await prefs.remove(key);
    }
  }
}

/// Auth changes invalidate asynchronous reads of a previous owner's preferences.
class OfferClosureScope {
  OfferClosureScope(
      {Future<List<OfferClosure>> Function(String)? read,
      DateTime Function()? now})
      : _read = read ?? OfferClosureInbox.read,
        _now = now ?? DateTime.now;
  final Future<List<OfferClosure>> Function(String) _read;
  final DateTime Function() _now;
  String? _owner;
  int _generation = 0;
  String? get owner => _owner;
  void bind(String? owner) {
    if (_owner == owner) return;
    _owner = owner;
    _generation++;
  }

  Future<bool> allows(
      {required String offerId,
      required String orderId,
      required DateTime expiresAt,
      String? cycleId}) async {
    final owner = _owner, generation = _generation;
    if (owner == null || !expiresAt.isAfter(_now())) return false;
    List<OfferClosure> closed;
    try {
      closed = await _read(owner);
    } catch (_) {
      return false;
    }
    return _owner == owner &&
        _generation == generation &&
        expiresAt.isAfter(_now()) &&
        !closed.any((c) =>
            c.matches(offerId: offerId, orderId: orderId, cycleId: cycleId));
  }
}
