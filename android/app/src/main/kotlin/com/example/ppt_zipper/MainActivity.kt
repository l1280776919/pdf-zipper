package com.example.ppt_zipper

import android.media.MediaScannerConnection
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ppt_zipper/media_store"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "scanFile") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    val file = File(filePath)
                    if (file.exists()) {
                        val mimeType = when {
                            filePath.endsWith(".pptx", ignoreCase = true) -> "application/vnd.openxmlformats-officedocument.presentationml.presentation"
                            filePath.endsWith(".ppt", ignoreCase = true) -> "application/vnd.ms-powerpoint"
                            else -> "*/*"
                        }
                        MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(file.absolutePath),
                            arrayOf(mimeType)
                        ) { _, _ -> }
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                } else {
                    result.error("INVALID_PATH", "filePath is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

