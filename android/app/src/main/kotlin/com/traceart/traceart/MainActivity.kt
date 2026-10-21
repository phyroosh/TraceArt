package com.traceart.traceart

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.traceart/system_lock"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLockTask" -> {
                    try {
                        startLockTask()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "stopLockTask" -> {
                    try {
                        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                        val isLocked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            activityManager?.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
                        } else {
                            @Suppress("DEPRECATION")
                            activityManager?.isInLockTaskMode ?: false
                        }
                        if (isLocked) {
                            stopLockTask()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isLockTaskActive" -> {
                    val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                    val isLocked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        activityManager?.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
                    } else {
                        @Suppress("DEPRECATION")
                        activityManager?.isInLockTaskMode ?: false
                    }
                    result.success(isLocked)
                }
                else -> result.notImplemented()
            }
        }
    }
}
