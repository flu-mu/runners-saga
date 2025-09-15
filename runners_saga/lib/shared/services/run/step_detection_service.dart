import 'dart:async';
import 'dart:math';

// Optional step counting abstraction.
// Uses pedometer if available, otherwise falls back to accelerometer-based detection via sensors_plus.

// These imports will require adding the packages to pubspec:
// pedometer and sensors_plus. If unavailable at build time, you can
// comment out one branch and rely on the other.
import 'package:pedometer/pedometer.dart' as pedo;
import 'package:sensors_plus/sensors_plus.dart' as sensors;
import 'package:permission_handler/permission_handler.dart';

typedef StepCallback = void Function(int stepDelta);

class StepDetectionService {
  StreamSubscription<pedo.StepCount>? _pedometerSub;
  StreamSubscription<sensors.AccelerometerEvent>? _accelSub;
  int _lastPedometerCount = 0;
  bool _usingPedometer = false;

  // Simple accelerometer-based detection state
  double _prevMagnitude = 0.0;
  DateTime _lastStepTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _accelSteps = 0;

  Future<void> start(StepCallback onStep) async {
    // On Android Q+ request ACTIVITY_RECOGNITION permission
    try {
      final status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        await Permission.activityRecognition.request();
      }
    } catch (_) {}

    // Try pedometer first
    try {
      _pedometerSub = pedo.Pedometer.stepCountStream.listen((event) {
        _usingPedometer = true;
        final current = event.steps;
        if (_lastPedometerCount == 0) {
          _lastPedometerCount = current;
          return;
        }
        final delta = max(0, current - _lastPedometerCount);
        _lastPedometerCount = current;
        if (delta > 0) onStep(delta);
      }, onError: (_) {});
      return; // Successfully started pedometer
    } catch (_) {
      // Fall through to accelerometer
    }

    // Fallback: accelerometer magnitude peak detection
    const double thresholdHigh = 11.5; // m/s^2, slightly above 1g (9.81)
    const double thresholdLow = 9.2;   // m/s^2, below 1g
    bool above = false;
    _accelSub = sensors.accelerometerEventStream().listen((e) {
      // Compute magnitude of acceleration vector
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      // Basic hysteresis to detect peaks
      if (!above && mag > thresholdHigh) {
        above = true;
      }
      if (above && mag < thresholdLow) {
        above = false;
        // Candidate step on falling edge
        final now = DateTime.now();
        if (now.difference(_lastStepTime).inMilliseconds > 300) { // debounce ~ 3.3 Hz
          _lastStepTime = now;
          _accelSteps += 1;
          onStep(1);
        }
      }
      _prevMagnitude = mag;
    });
  }

  Future<void> stop() async {
    await _pedometerSub?.cancel();
    await _accelSub?.cancel();
    _pedometerSub = null;
    _accelSub = null;
  }
}
