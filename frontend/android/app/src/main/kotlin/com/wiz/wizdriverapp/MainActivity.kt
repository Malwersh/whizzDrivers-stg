package com.wiz.wizdriverapp

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
 override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
  super.configureFlutterEngine(flutterEngine)
  SoundFiles.install(this, flutterEngine)
  io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.whizz.driver/location_label").setMethodCallHandler { call, result ->
   if (call.method != "describe") { result.notImplemented() }
   else {
    val lat = call.argument<Number>("latitude")?.toDouble()
    val lng = call.argument<Number>("longitude")?.toDouble()
    if (lat == null || lng == null || !lat.isFinite() || !lng.isFinite() || lat !in -90.0..90.0 || lng !in -180.0..180.0) { result.success(null) }
    else Thread {
     val label = try {
      @Suppress("DEPRECATION")
      val place = android.location.Geocoder(this, java.util.Locale("ar")).getFromLocation(lat, lng, 1)?.firstOrNull()
      listOfNotNull(place?.locality, place?.countryName).filter { it.isNotBlank() }.distinct().joinToString("، ").ifBlank { null }
     } catch (_: Exception) { null }
     runOnUiThread { result.success(label) }
    }.start()
   }
  }
 }
}
