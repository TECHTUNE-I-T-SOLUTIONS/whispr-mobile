package com.example.whisprmobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.whispr.whisprmobile/screenshot"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "disableScreenshot" -> {
                        disableScreenshot()
                        result.success(null)
                    }
                    "enableScreenshot" -> {
                        enableScreenshot()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun disableScreenshot() {
        window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    private fun enableScreenshot() {
        window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
