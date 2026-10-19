package com.wiz.wizdriverapp

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
 override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
  super.configureFlutterEngine(flutterEngine)
  SoundFiles.install(this, flutterEngine)
 }
}
