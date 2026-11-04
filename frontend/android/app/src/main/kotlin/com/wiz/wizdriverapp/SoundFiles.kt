package com.wiz.wizdriverapp
import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
object SoundFiles {
 fun install(context: Context, engine: FlutterEngine) {
  MethodChannel(engine.dartExecutor.binaryMessenger,"wizz/notification-sound-files").setMethodCallHandler { call,result ->
   if(call.method!="install"){result.notImplemented();return@setMethodCallHandler}
   try {
    val name=call.argument<String>("file")?:""
    val bytes=call.argument<ByteArray>("bytes")?:byteArrayOf()
    require(Regex("custom_[a-f0-9]{64}\\.wav").matches(name)&&bytes.size in 44..256000)
    val dir=File(context.filesDir,"notification-sounds");dir.mkdirs()
    val file=File(dir,name);if(!file.exists())file.writeBytes(bytes)
    val uri=FileProvider.getUriForFile(context,context.packageName+".notification-sounds",file)
    for(pkg in listOf("com.android.systemui","android"))context.grantUriPermission(pkg,uri,Intent.FLAG_GRANT_READ_URI_PERMISSION)
    result.success(mapOf("path" to file.absolutePath,"uri" to uri.toString()))
   } catch(e:Exception){result.error("SOUND_INSTALL_FAILED",null,null)}
  }
 }
}
