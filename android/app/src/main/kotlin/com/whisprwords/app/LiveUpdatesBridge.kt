package com.whisprwords.app

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** Dart -> native bridge for the home widget. Live Activity calls are iOS-only. */
object LiveUpdatesBridge {
    const val CHANNEL = "com.whispr.whisprmobile/live_updates"

    fun register(context: Context, flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        val args = call.arguments as? Map<*, *>
                        if (args == null) {
                            result.error("INVALID_ARGS", "Expected a snapshot map", null)
                            return@setMethodCallHandler
                        }
                        WidgetSnapshotStore.saveSnapshot(context, args.toJson())
                        WhisprWidgetProvider.updateAllWidgets(context)
                        result.success(true)
                    }
                    "isWidgetAttached" -> result.success(WhisprWidgetProvider.hasWidgets(context))
                    "refreshWidget" -> {
                        WhisprWidgetProvider.updateAllWidgets(context)
                        result.success(true)
                    }
                    // iOS Live Activities are driven by the AppDelegate bridge.
                    "startLiveActivity", "endLiveActivity" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
    }

    private fun Map<*, *>.toJson(): JSONObject {
        val json = JSONObject()
        forEach { (key, value) ->
            if (key is String) json.put(key, value)
        }
        return json
    }
}
