# GPS Tracking Optimization Implementation Plan

## Overview
This document outlines the planned optimizations for The Runner's Saga GPS tracking system, moving from the current "capture everything" approach to an intelligent, battery-aware tracking system.

## Current Implementation Status ✅
- **Distance Filter**: `distanceFilter: 0` (captures ALL positions)
- **Backup Timer**: 10-second manual position capture
- **Data Strategy**: Maximum accuracy, no position loss
- **Battery Impact**: High (constant GPS polling)

## Phase 1: Adaptive Sampling System 🎯

### 1.1 Movement Detection Algorithm
**File**: `lib/shared/services/progress_monitor_service.dart`

```dart
class MovementState {
  static const double _stationaryThreshold = 0.5; // meters per second
  static const double _slowMovementThreshold = 2.0; // meters per second
  static const double _fastMovementThreshold = 5.0; // meters per second
  
  static MovementType classifyMovement(double speed) {
    if (speed < _stationaryThreshold) return MovementType.stationary;
    if (speed < _slowMovementThreshold) return MovementType.slow;
    if (speed < _fastMovementThreshold) return MovementType.fast;
    return MovementType.sprint;
  }
}

enum MovementType {
  stationary,  // 0-0.5 m/s: 10 second intervals
  slow,       // 0.5-2 m/s: 5 second intervals  
  fast,       // 2-5 m/s: 2 second intervals
  sprint      // 5+ m/s: 1 second intervals
}
```

### 1.2 Adaptive GPS Intervals
**Implementation**: Replace current fixed intervals with movement-based sampling

```dart
class AdaptiveGpsSettings {
  static const Map<MovementType, Duration> _samplingIntervals = {
    MovementType.stationary: Duration(seconds: 10),
    MovementType.slow: Duration(seconds: 5),
    MovementType.fast: Duration(seconds: 2),
    MovementType.sprint: Duration(seconds: 1),
  };
  
  static Duration getSamplingInterval(MovementType movementType) {
    return _samplingIntervals[movementType] ?? Duration(seconds: 5);
  }
}
```

### 1.3 Speed Calculation Method
**Location**: `_onPositionUpdate()` method

```dart
void _onPositionUpdate(Position position) {
  if (!_isMonitoring) return;
  
  // Always add position to route
  _route.add(position);
  
  // Calculate current movement speed
  if (_lastPosition != null) {
    final distance = Geolocator.distanceBetween(
      _lastPosition!.latitude, _lastPosition!.longitude,
      position.latitude, position.longitude,
    );
    final timeDiff = position.timestamp.difference(_lastPosition!.timestamp);
    
    if (timeDiff.inSeconds > 0) {
      final speed = distance / timeDiff.inSeconds; // m/s
      final movementType = MovementState.classifyMovement(speed);
      
      // Adjust GPS sampling based on movement
      _adjustGpsSampling(movementType);
    }
  }
  
  _lastPosition = position;
  onRouteUpdate?.call(_route);
}
```

## Phase 2: Battery-Aware Tracking 🔋

### 2.1 Battery Level Detection
**Dependencies**: Add `battery_plus` package to `pubspec.yaml`

```yaml
dependencies:
  battery_plus: ^4.0.0
```

**Implementation**: Battery monitoring service

```dart
class BatteryAwareTracking {
  static const double _lowBatteryThreshold = 0.2; // 20%
  static const double _criticalBatteryThreshold = 0.1; // 10%
  
  static Future<BatteryLevel> getBatteryLevel() async {
    final battery = Battery();
    final level = await battery.batteryLevel;
    return BatteryLevel.values.firstWhere(
      (e) => e.threshold >= level / 100,
      orElse: () => BatteryLevel.high,
    );
  }
}

enum BatteryLevel {
  critical(0.1), // 0-10%: Minimal tracking
  low(0.2),      // 10-20%: Reduced tracking
  medium(0.5),   // 20-50%: Normal tracking
  high(1.0);     // 50%+: Full accuracy tracking
  
  const BatteryLevel(this.threshold);
  final double threshold;
}
```

### 2.2 Battery-Optimized Settings
**GPS Settings Matrix**:

| Battery Level | Stationary | Slow | Fast | Sprint |
|---------------|------------|------|------|---------|
| Critical (0-10%) | 30s | 20s | 10s | 5s |
| Low (10-20%) | 20s | 10s | 5s | 2s |
| Medium (20-50%) | 10s | 5s | 2s | 1s |
| High (50%+) | 10s | 5s | 2s | 1s |

**Implementation**:

```dart
class BatteryOptimizedGpsSettings {
  static Duration getSamplingInterval(MovementType movement, BatteryLevel battery) {
    final baseInterval = AdaptiveGpsSettings.getSamplingInterval(movement);
    
    switch (battery) {
      case BatteryLevel.critical:
        return Duration(seconds: baseInterval.inSeconds * 3);
      case BatteryLevel.low:
        return Duration(seconds: baseInterval.inSeconds * 2);
      case BatteryLevel.medium:
      case BatteryLevel.high:
        return baseInterval;
    }
  }
}
```

## Phase 3: Smart Data Management 🧠

### 3.1 GPS Noise Filtering
**Algorithm**: Kalman filter for position smoothing

```dart
class GpsNoiseFilter {
  static const double _accuracyThreshold = 20.0; // meters
  static const double _speedThreshold = 50.0; // m/s (unrealistic for running)
  
  static bool isValidPosition(Position position, Position? lastPosition) {
    // Check accuracy
    if (position.accuracy > _accuracyThreshold) return false;
    
    // Check for unrealistic speed jumps
    if (lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        lastPosition.latitude, lastPosition.longitude,
        position.latitude, position.longitude,
      );
      final timeDiff = position.timestamp.difference(lastPosition.timestamp);
      
      if (timeDiff.inSeconds > 0) {
        final speed = distance / timeDiff.inSeconds;
        if (speed > _speedThreshold) return false;
      }
    }
    
    return true;
  }
}
```

### 3.2 Route Data Compression
**Strategy**: Store high-level summary + compressed route

```dart
class CompressedRouteData {
  final List<LocationPoint> keyPoints;     // Important turns, start, end
  final List<LocationPoint> compressedRoute; // Compressed intermediate points
  final Map<String, dynamic> metadata;     // Distance, time, pace per segment
  
  // Compression ratio: typically 3:1 to 5:1
  // Original: 1000 points → Compressed: 200-300 points
  // Storage savings: 60-80%
}
```

**Compression Algorithm**:

```dart
class RouteCompressor {
  static const double _tolerance = 5.0; // meters
  
  static List<LocationPoint> compressRoute(List<LocationPoint> route) {
    if (route.length < 3) return route;
    
    final compressed = <LocationPoint>[route.first];
    
    for (int i = 1; i < route.length - 1; i++) {
      final prev = compressed.last;
      final current = route[i];
      final next = route[i + 1];
      
      // Douglas-Peucker algorithm for line simplification
      if (_perpendicularDistance(current, prev, next) > _tolerance) {
        compressed.add(current);
      }
    }
    
    compressed.add(route.last);
    return compressed;
  }
}
```

## Phase 4: Implementation Timeline 📅

### Week 1: Adaptive Sampling
- [ ] Implement `MovementState` classification
- [ ] Add adaptive GPS intervals
- [ ] Test movement detection accuracy
- [ ] Update GPS settings dynamically

### Week 2: Battery Optimization  
- [ ] Add `battery_plus` dependency
- [ ] Implement battery level detection
- [ ] Create battery-optimized GPS matrix
- [ ] Test battery impact reduction

### Week 3: Data Management
- [ ] Implement GPS noise filtering
- [ ] Add route compression algorithm
- [ ] Test data quality vs. storage efficiency
- [ ] Update Firestore storage strategy

### Week 4: Integration & Testing
- [ ] Combine all optimizations
- [ ] Performance testing
- [ ] Battery life testing
- [ ] User experience validation

## Performance Targets 🎯

### Battery Life Improvement
- **Current**: 2-3 hours continuous GPS tracking
- **Target**: 4-6 hours continuous GPS tracking
- **Method**: Reduce GPS polling frequency by 40-60%

### Data Storage Optimization
- **Current**: 1000 points = ~50KB per run
- **Target**: 1000 points = ~15-25KB per run
- **Method**: Compression + noise filtering

### Accuracy Maintenance
- **Current**: 100% position capture
- **Target**: 95%+ position capture (filtering noise)
- **Method**: Smart filtering preserves important points

## Testing Strategy 🧪

### 1. Movement Classification Test
```dart
void testMovementClassification() {
  // Test stationary detection
  assert(MovementState.classifyMovement(0.1) == MovementType.stationary);
  
  // Test slow movement
  assert(MovementState.classifyMovement(1.5) == MovementType.slow);
  
  // Test fast movement  
  assert(MovementState.classifyMovement(3.0) == MovementType.fast);
  
  // Test sprint
  assert(MovementState.classifyMovement(6.0) == MovementType.sprint);
}
```

### 2. Battery Impact Test
```dart
void testBatteryOptimization() {
  // Simulate low battery
  final lowBatterySettings = BatteryOptimizedGpsSettings.getSamplingInterval(
    MovementType.fast, 
    BatteryLevel.low
  );
  
  // Should return 10 seconds (2x normal)
  assert(lowBatterySettings.inSeconds == 10);
}
```

### 3. Data Quality Test
```dart
void testRouteCompression() {
  final originalRoute = generateTestRoute(1000);
  final compressedRoute = RouteCompressor.compressRoute(originalRoute);
  
  // Compression should reduce points by 60-80%
  final compressionRatio = compressedRoute.length / originalRoute.length;
  assert(compressionRatio >= 0.2 && compressionRatio <= 0.4);
  
  // Distance should remain accurate within 1%
  final originalDistance = calculateTotalDistance(originalRoute);
  final compressedDistance = calculateTotalDistance(compressedRoute);
  final accuracy = (compressedDistance / originalDistance).abs();
  assert(accuracy >= 0.99);
}
```

## Success Metrics 📊

### Primary KPIs
1. **Battery Life**: 40%+ improvement in GPS tracking duration
2. **Data Quality**: 95%+ position accuracy maintained
3. **Storage Efficiency**: 60%+ reduction in route data size
4. **User Experience**: No degradation in tracking accuracy

### Secondary KPIs  
1. **GPS Fix Time**: < 3 seconds cold start
2. **Position Accuracy**: < 10 meters 95% of the time
3. **Data Sync**: < 5 seconds to upload run data
4. **App Performance**: < 100ms route rendering time

## Risk Mitigation 🛡️

### Technical Risks
1. **Over-compression**: Implement quality checks and fallback to original data
2. **Battery detection failure**: Fallback to medium battery settings
3. **Movement misclassification**: Add confidence scoring and smoothing

### User Experience Risks
1. **Accuracy loss**: Extensive testing with real running data
2. **Battery drain**: Gradual rollout with A/B testing
3. **Data loss**: Backup uncompressed data for critical runs

## Conclusion 🎯

This optimization plan transforms The Runner's Saga from a "capture everything" GPS system to an intelligent, battery-aware tracking solution that maintains accuracy while significantly improving performance and user experience.

The phased approach ensures each optimization can be tested independently, reducing risk and allowing for iterative improvements based on real-world usage data.



























