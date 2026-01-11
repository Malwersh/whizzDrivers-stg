import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة التخزين المؤقت لحالة المطاعم لتحسين الأداء
/// نفس النظام المستخدم في تطبيق المستخدم
class BusinessStatusCache {
  static const String _cachePrefix = 'driver_business_status_';
  static const int _cacheExpirationMinutes = 1; // مدة صالحية الـ cache بالدقائق (للتحديثات السريعة)
  
  /// حفظ حالة المطعم في الذاكرة المؤقتة
  static Future<void> cacheBusinessStatus(
    String businessId, 
    Map<String, dynamic> statusData
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // إضافة timestamp للبيانات
      final cachedData = {
        ...statusData,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'expiresAt': DateTime.now().add(
          const Duration(minutes: _cacheExpirationMinutes)
        ).millisecondsSinceEpoch,
      };
      
      final cacheKey = '$_cachePrefix$businessId';
      final jsonString = json.encode(cachedData);
      
      await prefs.setString(cacheKey, jsonString);
      
      developer.log('💾 Driver: تم حفظ حالة المطعم في الذاكرة المؤقتة: $businessId');
    } catch (e) {
      developer.log('❌ Driver: خطأ في حفظ حالة المطعم في الذاكرة المؤقتة: $e');
    }
  }
  
  /// الحصول على حالة المطعم من الذاكرة المؤقتة
  static Future<Map<String, dynamic>?> getCachedBusinessStatus(
    String businessId
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$businessId';
      
      final jsonString = prefs.getString(cacheKey);
      if (jsonString == null) {
        developer.log('🔍 Driver: لا توجد بيانات مؤقتة للمطعم: $businessId');
        return null;
      }
      
      final cachedData = json.decode(jsonString) as Map<String, dynamic>;
      final expiresAt = cachedData['expiresAt'] as int?;
      
      // فحص إذا كانت البيانات منتهية الصلاحية
      if (expiresAt == null || DateTime.now().millisecondsSinceEpoch > expiresAt) {
        developer.log('⏰ Driver: البيانات المؤقتة منتهية الصلاحية للمطعم: $businessId');
        await clearCachedBusinessStatus(businessId);
        return null;
      }
      
      developer.log('✅ Driver: تم العثور على بيانات مؤقتة صالحة للمطعم: $businessId');
      return cachedData;
      
    } catch (e) {
      developer.log('❌ Driver: خطأ في قراءة البيانات المؤقتة: $e');
      return null;
    }
  }
  
  /// حذف حالة المطعم من الذاكرة المؤقتة
  static Future<void> clearCachedBusinessStatus(String businessId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$businessId';
      
      await prefs.remove(cacheKey);
      developer.log('🗑️ Driver: تم حذف البيانات المؤقتة للمطعم: $businessId');
    } catch (e) {
      developer.log('❌ Driver: خطأ في حذف البيانات المؤقتة: $e');
    }
  }
  
  /// حذف جميع البيانات المؤقتة لحالة المطاعم
  static Future<void> clearAllBusinessStatusCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final businessStatusKeys = keys.where(
        (key) => key.startsWith(_cachePrefix)
      ).toList();
      
      for (final key in businessStatusKeys) {
        await prefs.remove(key);
      }
      
      developer.log('🧹 Driver: تم حذف جميع البيانات المؤقتة لحالة المطاعم');
    } catch (e) {
      developer.log('❌ Driver: خطأ في حذف البيانات المؤقتة: $e');
    }
  }
  
  /// فحص صحة البيانات المؤقتة وحذف المنتهية الصلاحية
  static Future<void> cleanupExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final businessStatusKeys = keys.where(
        (key) => key.startsWith(_cachePrefix)
      ).toList();
      
      int cleanedCount = 0;
      
      for (final key in businessStatusKeys) {
        final jsonString = prefs.getString(key);
        if (jsonString == null) continue;
        
        try {
          final cachedData = json.decode(jsonString) as Map<String, dynamic>;
          final expiresAt = cachedData['expiresAt'] as int?;
          
          if (expiresAt == null || DateTime.now().millisecondsSinceEpoch > expiresAt) {
            await prefs.remove(key);
            cleanedCount++;
          }
        } catch (e) {
          // إذا كانت البيانات تالفة، احذفها
          await prefs.remove(key);
          cleanedCount++;
        }
      }
      
      if (cleanedCount > 0) {
        developer.log('🧹 Driver: تم حذف $cleanedCount من البيانات المؤقتة المنتهية الصلاحية');
      }
    } catch (e) {
      developer.log('❌ Driver: خطأ في تنظيف البيانات المؤقتة: $e');
    }
  }
  
  /// إجبار مسح الكاش للحصول على تحديثات فورية
  static Future<void> forceInvalidateBusinessStatus(String businessId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$businessId';
      
      // مسح البيانات المؤقتة فوراً
      await prefs.remove(cacheKey);
      
      developer.log('⚡ Driver: تم مسح الكاش فوراً للمطعم: $businessId');
    } catch (e) {
      developer.log('❌ Driver: خطأ في مسح الكاش الفوري: $e');
    }
  }
  
  /// فحص إذا كان هناك كاش قديم للمطعم
  static Future<bool> hasCachedData(String businessId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$businessId';
      return prefs.containsKey(cacheKey);
    } catch (e) {
      return false;
    }
  }

  /// الحصول على معلومات إحصائية عن الذاكرة المؤقتة
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final businessStatusKeys = keys.where(
        (key) => key.startsWith(_cachePrefix)
      ).toList();
      
      int totalCached = businessStatusKeys.length;
      int validCached = 0;
      int expiredCached = 0;
      
      for (final key in businessStatusKeys) {
        final jsonString = prefs.getString(key);
        if (jsonString == null) continue;
        
        try {
          final cachedData = json.decode(jsonString) as Map<String, dynamic>;
          final expiresAt = cachedData['expiresAt'] as int?;
          
          if (expiresAt != null && DateTime.now().millisecondsSinceEpoch <= expiresAt) {
            validCached++;
          } else {
            expiredCached++;
          }
        } catch (e) {
          expiredCached++;
        }
      }
      
      return {
        'totalCached': totalCached,
        'validCached': validCached,
        'expiredCached': expiredCached,
        'cacheExpirationMinutes': _cacheExpirationMinutes,
      };
    } catch (e) {
      developer.log('❌ Driver: خطأ في الحصول على إحصائيات الذاكرة المؤقتة: $e');
      return {
        'totalCached': 0,
        'validCached': 0,
        'expiredCached': 0,
        'cacheExpirationMinutes': _cacheExpirationMinutes,
      };
    }
  }
}
