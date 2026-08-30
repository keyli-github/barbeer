package com.barbeer.barbeer

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.barbeer.barbeer/files")
            .setMethodCallHandler { call, result ->
                if (call.method != "openFile") { result.notImplemented(); return@setMethodCallHandler }
                val path = call.argument<String>("path")
                    ?: run { result.error("INVALID_PATH", "path required", null); return@setMethodCallHandler }
                val mime = call.argument<String>("mimeType") ?: "*/*"
                try {
                    startActivity(Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(Uri.parse(path), mime)
                        flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
                    })
                    result.success(null)
                } catch (e: Exception) {
                    result.error("OPEN_FAILED", e.message, null)
                }
            }
    }
}
