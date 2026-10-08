package com.reeethepuffer.gateclosesapp

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // What the map's device ladder needs to pick the 3D or the lite map.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gate_closes/device")
            .setMethodCallHandler { call, result ->
                if (call.method != "mapCapabilities") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val activityManager =
                    getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val memory = ActivityManager.MemoryInfo()
                activityManager.getMemoryInfo(memory)
                result.success(
                    mapOf(
                        "totalRamMb" to (memory.totalMem / (1024 * 1024)).toInt(),
                        "lowRam" to activityManager.isLowRamDevice,
                        "sdk" to Build.VERSION.SDK_INT,
                    )
                )
            }
    }
}
