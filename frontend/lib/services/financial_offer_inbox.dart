import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'financial_offer_reference.dart';

/// A push is a reference, never an offer price or authority to accept it.
/// Separate keys avoid overwriting other offers across Firebase isolates.
class FinancialOfferInbox {
  static const prefix='financialOfferInbox.v1.';
  static final _events=StreamController<Map<String,dynamic>>.broadcast();
  static Stream<Map<String,dynamic>> get events=>_events.stream;
  static String _key(Map<String,dynamic> r)=>prefix+base64Url.encode(utf8.encode('${r['driverId']}|${r['offerId']}|${r['cycleId']}'));
  static Future<Map<String,dynamic>> record(Map<String,dynamic> data)async{
    final reference=FinancialOfferReference.read(data);
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString(_key(reference),jsonEncode({...reference,'type':'financial_wave_offer_available'}));
    _events.add(Map<String,dynamic>.unmodifiable({...reference,'type':'financial_wave_offer_available'}));
    return reference;
  }
  static Future<List<Map<String,dynamic>>> pending(String owner)async{
    final prefs=await SharedPreferences.getInstance();await prefs.reload();
    final result=<Map<String,dynamic>>[];
    for(final key in prefs.getKeys().where((k)=>k.startsWith(prefix)).toList()){
      try{
        final data=Map<String,dynamic>.from(jsonDecode(prefs.getString(key)!));
        final reference=FinancialOfferReference.read(data);
        if(reference['driverId']==owner)result.add({...reference,'type':'financial_wave_offer_available'});
      }catch(_){await prefs.remove(key);}
    }
    result.sort((a,b)=>a['expiresAt'].toString().compareTo(b['expiresAt'].toString()));
    return result;
  }
  static Future<void> remove(Map<String,dynamic> reference)async{
    final prefs=await SharedPreferences.getInstance();await prefs.remove(_key(reference));
  }
  static Future<void> clear()async{
    final prefs=await SharedPreferences.getInstance();await prefs.reload();
    for(final key in prefs.getKeys().where((k)=>k.startsWith(prefix)).toList()){await prefs.remove(key);}
  }
}
