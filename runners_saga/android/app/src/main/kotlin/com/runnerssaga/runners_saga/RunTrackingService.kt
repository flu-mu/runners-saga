package com.runnerssaga.runners_saga

import android.app.*
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.content.Context
import android.app.NotificationChannel
import android.os.Build
import android.util.Log
import android.location.Location
import android.location.LocationManager
import android.location.LocationListener
import android.location.LocationRequest
import android.os.Looper
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import android.Manifest
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.*

class RunTrackingService : Service() {
    private val binder = RunTrackingBinder()
    private var wakeLock: PowerManager.WakeLock? = null
    
    // GPS tracking
    private lateinit var locationManager: LocationManager
    private var locationListener: LocationListener? = null
    private var isLocationTracking = false
    private var lastLocation: Location? = null
    private val locationList = mutableListOf<Location>()
    
    // Timer tracking
    private var startTime: Long = 0
    private var isTimerRunning = false
    private var timerExecutor: ScheduledExecutorService? = null
    
    // Run session data
    private var runId: String? = null
    private var episodeTitle: String? = null
    private var targetTimeSeconds: Int = 0
    private var targetDistance: Double = 0.0
    
    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "run_tracking_channel"
        private const val TAG = "RunTrackingService"
        
        fun startService(context: Context) {
            val intent = Intent(context, RunTrackingService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stopService(context: Context) {
            val intent = Intent(context, RunTrackingService::class.java)
            context.stopService(intent)
        }
        
        fun isServiceRunning(context: Context): Boolean {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            for (service in manager.getRunningServices(Integer.MAX_VALUE)) {
                if (RunTrackingService::class.java.name == service.service.className) {
                    return true
                }
            }
            return false
        }
    }
    
    inner class RunTrackingBinder : Binder() {
        fun getService(): RunTrackingService = this@RunTrackingService
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "RunTrackingService created")
        
        // Initialize location manager
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        
        createNotificationChannel()
        acquireWakeLock()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "RunTrackingService started")
        
        // Handle different intents
        when (intent?.action) {
            "START_RUN_SESSION" -> {
                val runId = intent.getStringExtra("runId")
                val episodeTitle = intent.getStringExtra("episodeTitle")
                val targetTime = intent.getIntExtra("targetTime", 0)
                val targetDistance = intent.getDoubleExtra("targetDistance", 0.0)
                
                startRunSession(runId, episodeTitle, targetTime, targetDistance)
            }
            "UPDATE_NOTIFICATION" -> {
                val title = intent.getStringExtra("title") ?: "Runners Saga"
                val content = intent.getStringExtra("content") ?: "Tracking your run..."
                updateNotification(title, content)
            }
            "STOP_RUN_SESSION" -> {
                stopRunSession()
            }
            else -> {
                // Default startup
                val notification = createNotification()
                startForeground(NOTIFICATION_ID, notification)
            }
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder {
        return binder
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "RunTrackingService destroyed")
        
        stopLocationTracking()
        stopTimer()
        releaseWakeLock()
    }
    
    /// Start a run session with GPS tracking and timer
    private fun startRunSession(runId: String?, episodeTitle: String?, targetTime: Int, targetDistance: Double) {
        this.runId = runId
        this.episodeTitle = episodeTitle
        this.targetTimeSeconds = targetTime
        this.targetDistance = targetDistance
        
        Log.d(TAG, "Starting run session: $episodeTitle, Target: ${targetTime}s, ${targetDistance}km")
        
        // Start timer
        startTimer()
        
        // Start GPS tracking
        startLocationTracking()
        
        // Update notification
        updateNotification(
            "Runners Saga - $episodeTitle",
            "Tracking your run... Tap to open app"
        )
        
        // Send event to Flutter
        sendEventToFlutter("SESSION_STARTED")
    }
    
    /// Stop the current run session
    private fun stopRunSession() {
        Log.d(TAG, "Stopping run session")
        
        stopTimer()
        stopLocationTracking()
        
        // Clear session data
        runId = null
        episodeTitle = null
        targetTimeSeconds = 0
        targetDistance = 0.0
        
        // Send event to Flutter
        sendEventToFlutter("SESSION_STOPPED")
    }
    
    /// Start the timer for tracking elapsed time
    private fun startTimer() {
        if (isTimerRunning) return
        
        startTime = System.currentTimeMillis()
        isTimerRunning = true
        
        timerExecutor = Executors.newScheduledThreadPool(1)
        timerExecutor?.scheduleAtFixedRate({
            if (isTimerRunning) {
                val elapsedSeconds = (System.currentTimeMillis() - startTime) / 1000
                sendTimerUpdate(elapsedSeconds)
                
                // Update notification every 30 seconds
                if (elapsedSeconds % 30 == 0) {
                    updateTimerNotification(elapsedSeconds)
                }
            }
        }, 0, 1, TimeUnit.SECONDS)
        
        Log.d(TAG, "Timer started")
    }
    
    /// Stop the timer
    private fun stopTimer() {
        isTimerRunning = false
        timerExecutor?.shutdown()
        timerExecutor = null
        Log.d(TAG, "Timer stopped")
    }
    
    /// Start GPS location tracking
    private fun startLocationTracking() {
        if (isLocationTracking) return
        
        // Check permissions
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "Location permission not granted")
            return
        }
        
        try {
            // Create location listener
            locationListener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    handleLocationUpdate(location)
                }
                
                override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }
            
            // Request location updates
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                5000, // 5 seconds
                0f,   // 0 meters
                locationListener!!,
                Looper.getMainLooper()
            )
            
            // Also request network provider updates as backup
            locationManager.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER,
                10000, // 10 seconds
                0f,    // 0 meters
                locationListener!!,
                Looper.getMainLooper()
            )
            
            isLocationTracking = true
            Log.d(TAG, "Location tracking started")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error starting location tracking: $e")
        }
    }
    
    /// Stop GPS location tracking
    private fun stopLocationTracking() {
        if (!isLocationTracking) return
        
        try {
            locationListener?.let { listener ->
                locationManager.removeUpdates(listener)
            }
            locationListener = null
            isLocationTracking = false
            Log.d(TAG, "Location tracking stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping location tracking: $e")
        }
    }
    
    /// Handle location updates
    private fun handleLocationUpdate(location: Location) {
        lastLocation = location
        locationList.add(location)
        
        // Calculate distance if we have previous locations
        if (locationList.size > 1) {
            val previousLocation = locationList[locationList.size - 2]
            val distance = location.distanceTo(previousLocation) / 1000.0 // Convert to kilometers
            
            Log.d(TAG, "Location update: (${location.latitude}, ${location.longitude}), Distance: ${String.format("%.3f", distance)}km")
            
            // Send GPS update to Flutter
            sendGpsUpdate(location, distance)
        } else {
            Log.d(TAG, "First location: (${location.latitude}, ${location.longitude})")
        }
        
        // Limit location list size to prevent memory issues
        if (locationList.size > 1000) {
            locationList.removeAt(0)
        }
    }
    
    /// Send timer update to Flutter
    private fun sendTimerUpdate(elapsedSeconds: Long) {
        val event = "TIMER_UPDATE:$elapsedSeconds:$isTimerRunning"
        sendEventToFlutter(event)
    }
    
    /// Send GPS update to Flutter
    private fun sendGpsUpdate(location: Location, distance: Double) {
        val event = "GPS_UPDATE:${location.latitude}:${location.longitude}:${location.accuracy}:$distance"
        sendEventToFlutter(event)
    }
    
    /// Send event to Flutter via method channel
    private fun sendEventToFlutter(event: String) {
        try {
            // This will be received by the Flutter side via EventChannel
            Log.d(TAG, "Sending event to Flutter: $event")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending event to Flutter: $e")
        }
    }
    
    /// Update notification with timer information
    private fun updateTimerNotification(elapsedSeconds: Long) {
        val minutes = elapsedSeconds / 60
        val seconds = elapsedSeconds % 60
        val timeString = String.format("%02d:%02d", minutes, seconds)
        
        val content = if (episodeTitle != null) {
            "$episodeTitle - $timeString elapsed"
        } else {
            "Run in progress - $timeString elapsed"
        }
        
        updateNotification("Runners Saga", content)
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Run Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps your run tracking active in the background"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Runners Saga")
            .setContentText("Tracking your run...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "RunnersSaga::RunTrackingWakeLock"
        ).apply {
            acquire(10*60*1000L) // 10 minutes timeout
        }
        Log.d(TAG, "Wake lock acquired")
    }
    
    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                Log.d(TAG, "Wake lock released")
            }
        }
        wakeLock = null
    }
    
    fun updateNotification(title: String, content: String) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        
        val notificationManager = NotificationManagerCompat.from(this)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    /// Get current service status
    fun getServiceStatus(): Map<String, Any> {
        return mapOf(
            "isRunning" to true,
            "isLocationTracking" to isLocationTracking,
            "isTimerRunning" to isTimerRunning,
            "elapsedSeconds" to (if (isTimerRunning) (System.currentTimeMillis() - startTime) / 1000 else 0L),
            "locationCount" to locationList.size,
            "runId" to (runId ?: ""),
            "episodeTitle" to (episodeTitle ?: ""),
            "targetTimeSeconds" to targetTimeSeconds,
            "targetDistance" to targetDistance
        )
    }
}
