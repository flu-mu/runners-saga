package com.runnerssaga.runners_saga

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Build
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "runners_saga/background_service"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundService" -> {
                    try {
                        val runId = call.argument<String>("runId") ?: ""
                        val episodeTitle = call.argument<String>("episodeTitle") ?: ""
                        val targetTime = call.argument<Int>("targetTime") ?: 0
                        val targetDistance = call.argument<Double>("targetDistance") ?: 0.0
                        
                        Log.d("MainActivity", "Starting background service for run: $runId")
                        RunTrackingService.startService(this)
                        
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error starting background service: $e")
                        result.error("SERVICE_ERROR", "Failed to start service", e.message)
                    }
                }
                
                "stopBackgroundService" -> {
                    try {
                        Log.d("MainActivity", "Stopping background service")
                        RunTrackingService.stopService(this)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error stopping background service: $e")
                        result.error("SERVICE_ERROR", "Failed to stop service", e.message)
                    }
                }
                
                "updateNotification" -> {
                    try {
                        val title = call.argument<String>("title") ?: "Runners Saga"
                        val content = call.argument<String>("content") ?: "Tracking your run..."
                        
                        // Update notification through the service
                        val intent = Intent(this, RunTrackingService::class.java)
                        intent.action = "UPDATE_NOTIFICATION"
                        intent.putExtra("title", title)
                        intent.putExtra("content", content)
                        startService(intent)
                        
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error updating notification: $e")
                        result.error("NOTIFICATION_ERROR", "Failed to update notification", e.message)
                    }
                }
                
                "startRunSession" -> {
                    try {
                        val runId = call.argument<String>("runId") ?: ""
                        val episodeTitle = call.argument<String>("episodeTitle") ?: ""
                        val targetTime = call.argument<Int>("targetTime") ?: 0
                        val targetDistance = call.argument<Double>("targetDistance") ?: 0.0
                        
                        Log.d("MainActivity", "Starting run session: $runId")
                        
                        // Start the service first
                        RunTrackingService.startService(this)
                        
                        // Send the run session data to the service
                        val intent = Intent(this, RunTrackingService::class.java)
                        intent.action = "START_RUN_SESSION"
                        intent.putExtra("runId", runId)
                        intent.putExtra("episodeTitle", episodeTitle)
                        intent.putExtra("targetTime", targetTime)
                        intent.putExtra("targetDistance", targetDistance)
                        startService(intent)
                        
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error starting run session: $e")
                        result.error("SESSION_ERROR", "Failed to start run session", e.message)
                    }
                }
                
                "stopRunSession" -> {
                    try {
                        Log.d("MainActivity", "Stopping run session")
                        
                        // Send stop command to service
                        val intent = Intent(this, RunTrackingService::class.java)
                        intent.action = "STOP_RUN_SESSION"
                        startService(intent)
                        
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error stopping run session: $e")
                        result.error("SESSION_ERROR", "Failed to stop run session", e.message)
                    }
                }
                
                "isBackgroundServiceRunning" -> {
                    try {
                        // Check if the service is actually running
                        val isRunning = RunTrackingService.isServiceRunning(this)
                        Log.d("MainActivity", "Background service running: $isRunning")
                        result.success(isRunning)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error checking service status: $e")
                        result.success(false)
                    }
                }
                
                "requestBatteryOptimizationExemption" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            intent.data = android.net.Uri.parse("package:$packageName")
                            intent.putExtra("package", packageName)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error requesting battery optimization exemption: $e")
                        result.error("BATTERY_ERROR", "Failed to request exemption", e.message)
                    }
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
