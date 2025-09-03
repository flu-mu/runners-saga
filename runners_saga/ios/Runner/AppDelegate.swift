import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up method channel after Flutter engine is ready
    DispatchQueue.main.async {
      self.setupMethodChannel()
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupMethodChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      print("iOS: Root view controller not available yet, retrying...")
      // Retry after a short delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.setupMethodChannel()
      }
      return
    }
    
    let backgroundServiceChannel = FlutterMethodChannel(name: "runners_saga/background_service",
                                                      binaryMessenger: controller.binaryMessenger)
    
    backgroundServiceChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "startBackgroundService":
        // iOS doesn't support true background services like Android
        // We'll return success but log that it's not fully implemented
        print("iOS: startBackgroundService called (limited support)")
        result(true)
        
      case "stopBackgroundService":
        print("iOS: stopBackgroundService called")
        result(true)
        
      case "updateNotification":
        print("iOS: updateNotification called")
        result(true)
        
      case "isBackgroundServiceRunning":
        // iOS background services are limited, return false
        print("iOS: isBackgroundServiceRunning called")
        result(false)
        
      case "requestBatteryOptimizationExemption":
        // iOS doesn't have battery optimization like Android
        print("iOS: requestBatteryOptimizationExemption called (not applicable)")
        result(false)
        
      case "startRunSession":
        print("iOS: startRunSession called")
        result(true)
        
      case "stopRunSession":
        print("iOS: stopRunSession called")
        result(true)
        
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    print("iOS: Background service method channel set up successfully")
  }
}
