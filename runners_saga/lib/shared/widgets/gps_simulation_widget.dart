import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/gps_simulation_service.dart';
import '../../core/constants/app_theme.dart';

/// Widget for controlling GPS simulation during development/testing
class GpsSimulationWidget extends ConsumerStatefulWidget {
  final GpsSimulationService simulationService;
  final Function(Position)? onPositionUpdate;
  
  const GpsSimulationWidget({
    super.key,
    required this.simulationService,
    this.onPositionUpdate,
  });

  @override
  ConsumerState<GpsSimulationWidget> createState() => _GpsSimulationWidgetState();
}

class _GpsSimulationWidgetState extends ConsumerState<GpsSimulationWidget> {
  bool _isSimulating = false;
  int _currentWaypointIndex = 0;
  int _totalWaypoints = 0;
  double _progress = 0.0;
  
  @override
  void initState() {
    super.initState();
    _updateStatus();
    
    // Set up position update callback
    widget.simulationService.onPositionUpdate = (position) {
      widget.onPositionUpdate?.call(position);
      _updateStatus();
    };
  }
  
  void _updateStatus() {
    setState(() {
      _isSimulating = widget.simulationService.isSimulating;
      _currentWaypointIndex = widget.simulationService.currentWaypointIndex;
      _totalWaypoints = widget.simulationService.totalWaypoints;
      _progress = widget.simulationService.progress;
    });
  }
  
  Future<void> _loadGpxFile() async {
    await widget.simulationService.loadGpxFile('assets/gps/salerno_5km_run.gpx');
    _updateStatus();
  }
  
  void _startSimulation() {
    widget.simulationService.startSimulation(
      interval: const Duration(seconds: 2),
      loop: false,
    );
    _updateStatus();
  }
  
  void _stopSimulation() {
    widget.simulationService.stopSimulation();
    _updateStatus();
  }
  
  void _resetSimulation() {
    widget.simulationService.stopSimulation();
    widget.simulationService.jumpToWaypoint(0);
    _updateStatus();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kElectricAqua.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.gps_fixed,
                color: kElectricAqua,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'GPS Simulation',
                style: TextStyle(
                  color: kElectricAqua,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isSimulating ? kMeadowGreen : kTextMid.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isSimulating ? 'RUNNING' : 'STOPPED',
                  style: TextStyle(
                    color: _isSimulating ? Colors.white : kTextMid,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Status info
          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  'Waypoints',
                  '$_currentWaypointIndex / $_totalWaypoints',
                  Icons.flag,
                  kEmberCoral,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusCard(
                  'Progress',
                  '${(_progress * 100).toStringAsFixed(1)}%',
                  Icons.trending_up,
                  kElectricAqua,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress bar
          if (_totalWaypoints > 0) ...[
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: kTextMid.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(kElectricAqua),
            ),
            const SizedBox(height: 16),
          ],
          
          // Current waypoint info
          if (widget.simulationService.currentWaypoint != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kMidnightNavy.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kElectricAqua.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: kElectricAqua,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.simulationService.currentWaypoint!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.simulationService.currentWaypoint!.latitude.toStringAsFixed(5)}, ${widget.simulationService.currentWaypoint!.longitude.toStringAsFixed(5)}',
                          style: TextStyle(
                            color: kTextMid,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Control buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadGpxFile,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Load GPX'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSurfaceBase,
                    foregroundColor: kElectricAqua,
                    side: BorderSide(color: kElectricAqua),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSimulating ? _stopSimulation : _startSimulation,
                  icon: Icon(_isSimulating ? Icons.stop : Icons.play_arrow),
                  label: Text(_isSimulating ? 'Stop' : 'Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSimulating ? kEmberCoral : kElectricAqua,
                    foregroundColor: _isSimulating ? Colors.white : kMidnightNavy,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _resetSimulation,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSurfaceBase,
                    foregroundColor: kTextMid,
                    side: BorderSide(color: kTextMid.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Info text
          Text(
            'This widget simulates GPS coordinates from the Salerno 5km run GPX file. Use it to test the running functionality without real GPS.',
            style: TextStyle(
              color: kTextMid,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: kTextMid,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
