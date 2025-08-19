import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:xml/xml.dart';

/// Service for simulating GPS coordinates from GPX files
class GpsSimulationService {
  static const String _defaultGpxFile = 'assets/gps/salerno_5km_run.gpx';
  
  List<GpsWaypoint> _waypoints = [];
  int _currentWaypointIndex = 0;
  Timer? _simulationTimer;
  bool _isSimulating = false;
  
  // Callback for position updates
  Function(Position)? onPositionUpdate;
  
  /// Load GPX file and parse waypoints
  Future<void> loadGpxFile(String gpxFilePath) async {
    try {
      String gpxContent;
      
      if (gpxFilePath.startsWith('assets/')) {
        // Load from assets
        gpxContent = await rootBundle.loadString(gpxFilePath);
      } else {
        // Load from file system
        final file = File(gpxFilePath);
        gpxContent = await file.readAsString();
      }
      
      _parseGpxContent(gpxContent);
      print('🎯 GPS Simulation: Loaded ${_waypoints.length} waypoints from $gpxFilePath');
    } catch (e) {
      print('❌ GPS Simulation: Failed to load GPX file: $e');
      // Load default file as fallback
      await _loadDefaultGpxFile();
    }
  }
  
  /// Load the default Salerno 5km run GPX file
  Future<void> _loadDefaultGpxFile() async {
    try {
      final gpxContent = await rootBundle.loadString(_defaultGpxFile);
      _parseGpxContent(gpxContent);
      print('🎯 GPS Simulation: Loaded default GPX file with ${_waypoints.length} waypoints');
    } catch (e) {
      print('❌ GPS Simulation: Failed to load default GPX file: $e');
      // Create a simple fallback route
      _createFallbackRoute();
    }
  }
  
  /// Parse GPX content and extract waypoints
  void _parseGpxContent(String gpxContent) {
    try {
      final document = XmlDocument.parse(gpxContent);
      final waypointElements = document.findAllElements('wpt');
      
      _waypoints.clear();
      
      for (final element in waypointElements) {
        final lat = double.tryParse(element.getAttribute('lat') ?? '0') ?? 0.0;
        final lon = double.tryParse(element.getAttribute('lon') ?? '0') ?? 0.0;
        final name = element.findElements('name').firstOrNull?.text ?? 'Unknown';
        final timeStr = element.findElements('time').firstOrNull?.text ?? '';
        
        DateTime? time;
        if (timeStr.isNotEmpty) {
          try {
            time = DateTime.parse(timeStr);
          } catch (e) {
            time = DateTime.now();
          }
        } else {
          time = DateTime.now();
        }
        
        _waypoints.add(GpsWaypoint(
          latitude: lat,
          longitude: lon,
          name: name,
          timestamp: time,
        ));
      }
      
      // Sort waypoints by timestamp if available
      if (_waypoints.isNotEmpty && _waypoints.first.timestamp != null) {
        _waypoints.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
      }
      
      print('🎯 GPS Simulation: Parsed ${_waypoints.length} waypoints');
    } catch (e) {
      print('❌ GPS Simulation: Failed to parse GPX content: $e');
      _createFallbackRoute();
    }
  }
  
  /// Create a simple fallback route if GPX parsing fails
  void _createFallbackRoute() {
    _waypoints = [
      GpsWaypoint(latitude: 40.6728, longitude: 14.7675, name: 'Start', timestamp: DateTime.now()),
      GpsWaypoint(latitude: 40.6710, longitude: 14.7800, name: 'Midpoint', timestamp: DateTime.now().add(const Duration(minutes: 2))),
      GpsWaypoint(latitude: 40.6690, longitude: 14.7925, name: 'Turnaround', timestamp: DateTime.now().add(const Duration(minutes: 4))),
      GpsWaypoint(latitude: 40.6710, longitude: 14.7800, name: 'Return Midpoint', timestamp: DateTime.now().add(const Duration(minutes: 6))),
      GpsWaypoint(latitude: 40.6728, longitude: 14.7675, name: 'Finish', timestamp: DateTime.now().add(const Duration(minutes: 8))),
    ];
    print('🎯 GPS Simulation: Created fallback route with ${_waypoints.length} waypoints');
  }
  
  /// Start GPS simulation
  void startSimulation({
    Duration interval = const Duration(seconds: 2),
    bool loop = false,
  }) {
    if (_waypoints.isEmpty) {
      print('⚠️ GPS Simulation: No waypoints loaded, cannot start simulation');
      return;
    }
    
    if (_isSimulating) {
      print('⚠️ GPS Simulation: Simulation already running');
      return;
    }
    
    _isSimulating = true;
    _currentWaypointIndex = 0;
    
    print('🎯 GPS Simulation: Starting simulation with ${_waypoints.length} waypoints, interval: $interval');
    
    _simulationTimer = Timer.periodic(interval, (timer) {
      if (_currentWaypointIndex < _waypoints.length) {
        final waypoint = _waypoints[_currentWaypointIndex];
        final position = _createPositionFromWaypoint(waypoint);
        
        print('🎯 GPS Simulation: Waypoint ${_currentWaypointIndex + 1}/${_waypoints.length}: ${waypoint.name} (${waypoint.latitude}, ${waypoint.longitude})');
        
        onPositionUpdate?.call(position);
        _currentWaypointIndex++;
      } else {
        if (loop) {
          _currentWaypointIndex = 0;
          print('🎯 GPS Simulation: Looping back to start');
        } else {
          stopSimulation();
          print('🎯 GPS Simulation: Simulation completed');
        }
      }
    });
  }
  
  /// Stop GPS simulation
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isSimulating = false;
    print('🎯 GPS Simulation: Simulation stopped');
  }
  
  /// Create a Position object from a waypoint
  Position _createPositionFromWaypoint(GpsWaypoint waypoint) {
    return Position(
      latitude: waypoint.latitude,
      longitude: waypoint.longitude,
      timestamp: waypoint.timestamp ?? DateTime.now(),
      accuracy: 5.0, // Simulated accuracy
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }
  
  /// Get current simulation status
  bool get isSimulating => _isSimulating;
  
  /// Get current waypoint index
  int get currentWaypointIndex => _currentWaypointIndex;
  
  /// Get total waypoints
  int get totalWaypoints => _waypoints.length;
  
  /// Get current progress (0.0 to 1.0)
  double get progress {
    if (_waypoints.isEmpty) return 0.0;
    return _currentWaypointIndex / _waypoints.length;
  }
  
  /// Jump to a specific waypoint index
  void jumpToWaypoint(int index) {
    if (index >= 0 && index < _waypoints.length) {
      _currentWaypointIndex = index;
      print('🎯 GPS Simulation: Jumped to waypoint $index: ${_waypoints[index].name}');
    }
  }
  
  /// Get current waypoint
  GpsWaypoint? get currentWaypoint {
    if (_currentWaypointIndex < _waypoints.length) {
      return _waypoints[_currentWaypointIndex];
    }
    return null;
  }
  
  /// Get all waypoints
  List<GpsWaypoint> get waypoints => List.unmodifiable(_waypoints);
  
  /// Dispose resources
  void dispose() {
    stopSimulation();
    _waypoints.clear();
  }
}

/// Data class for GPS waypoints
class GpsWaypoint {
  final double latitude;
  final double longitude;
  final String name;
  final DateTime? timestamp;
  
  GpsWaypoint({
    required this.latitude,
    required this.longitude,
    required this.name,
    this.timestamp,
  });
  
  @override
  String toString() {
    return 'GpsWaypoint($name: $latitude, $longitude)';
  }
}



