import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../shared/providers/run_session_providers.dart';
import '../../../shared/models/run_model.dart';
import '../../../core/constants/app_theme.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';

class RunMapPanel extends ConsumerStatefulWidget {
  /// When true, the panel expands to fill available height without
  /// imposing the default min/max constraints.
  final bool expanded;

  const RunMapPanel({super.key, this.expanded = false});

  @override
  ConsumerState<RunMapPanel> createState() => _RunMapPanelState();
}

class _RunMapPanelState extends ConsumerState<RunMapPanel> {
  final MapController _mapController = MapController();
  LatLng? _liveCenter; // first GPS fix when route is not yet populated

  @override
  Widget build(BuildContext context) {
    // Watch live stats so this widget rebuilds as the route updates
    final stats = ref.watch(currentRunStatsProvider);
    // Fallback to pulling from the manager if stats are not yet available
    final sessionManager = ref.read(runSessionControllerProvider.notifier);
    final currentRoute = stats?.route ?? sessionManager.getCurrentRoute();
    
    // No fallback location: world view until GPS arrives
    final bool hasRouteGps = currentRoute.isNotEmpty;
    final LatLng? centerCandidate = hasRouteGps
        ? LatLng(currentRoute.last.latitude, currentRoute.last.longitude)
        : _liveCenter;

    // If we have neither route GPS nor live GPS yet, fetch immediately
    if (!hasRouteGps && _liveCenter == null) {
      // fire and forget; setState when available
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((pos) {
        if (mounted) {
          setState(() {
            _liveCenter = LatLng(pos.latitude, pos.longitude);
            // also move map if it's already built
            _mapController.move(_liveCenter!, 15);
          });
        }
      }).catchError((_) {});
    }

    final polylinePoints = currentRoute
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();

    // Fit camera to route when we have enough points
    if (polylinePoints.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final bounds = LatLngBounds.fromPoints(polylinePoints);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(32)),
        );
      });
    }

    final decoration = BoxDecoration(
      color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );

    final child = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: centerCandidate ?? const LatLng(0, 0),
              initialZoom: (centerCandidate != null) ? 15 : 2.5,
              maxZoom: 18,
              minZoom: 1,
              // Prevent map from being too zoomed out
              onMapReady: () {
                if (centerCandidate != null) {
                  _mapController.move(centerCandidate, 15);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'runners_saga',
              ),
              // Add KM markers layer
              if (polylinePoints.length > 1) _buildKmMarkers(polylinePoints),
              // Route polyline
              if (polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polylinePoints, 
                      color: Theme.of(context).colorScheme.primary, 
                      strokeWidth: 4,
                    ),
                  ],
                ),
              // Current position marker - only when we have a GPS center
              if (centerCandidate != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: centerCandidate,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.my_location,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Map controls overlay
          Positioned(
            top: 8,
            right: 8,
            child: Column(
              children: [
                // Zoom in button
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    ),
                    icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary, size: 20),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
                const SizedBox(height: 8),
                // Zoom out button
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    ),
                    icon: Icon(Icons.remove, color: Theme.of(context).colorScheme.primary, size: 20),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
                const SizedBox(height: 8),
                // Fit route button
                if (polylinePoints.length > 1)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () {
                        final bounds = LatLngBounds.fromPoints(polylinePoints);
                        _mapController.fitCamera(
                          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(32)),
                        );
                      },
                      icon: Icon(Icons.fit_screen, color: Theme.of(context).colorScheme.primary, size: 20),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // If expanded, do not apply tight height constraints so the parent
    // Expanded can size it. Otherwise, keep the compact card sizing.
    if (widget.expanded) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: decoration,
        child: child,
      );
    }

    return Container(
      // Default compact height for list/scroll views
      constraints: const BoxConstraints(
        minHeight: 200,
        maxHeight: 300,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: decoration,
      child: child,
    );
  }

  /// Build KM markers along the route
  Widget _buildKmMarkers(List<LatLng> points) {
    if (points.length < 2) return const SizedBox.shrink();

    final markers = <Marker>[];
    double totalDistance = 0;
    
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      
      // Calculate distance between points (rough approximation)
      final distance = _calculateDistance(prev, curr);
      totalDistance += distance;
      
      // Add marker every 1km
      if (totalDistance >= 1.0) {
        markers.add(Marker(
          point: curr,
          width: 40,
          height: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiary.withOpacity(0.9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 1),
            ),
            child: Text(
              '${totalDistance.toInt()}km',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ));
        
        // Reset for next km
        totalDistance = 0;
      }
    }
    
    return MarkerLayer(markers: markers);
  }

  /// Calculate approximate distance between two points in km
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in km
    
    final lat1 = point1.latitude * (pi / 180);
    final lat2 = point2.latitude * (pi / 180);
    final deltaLat = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLon = (point2.longitude - point1.longitude) * (pi / 180);
    
    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
}
