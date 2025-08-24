# GPS Simulation for Runners Saga

This directory contains GPS simulation files and tools for testing the running functionality without real GPS hardware.

## Files

### `salerno_5km_run.gpx`
A GPX file containing a simulated 5km run route along the waterfront in Salerno, Italy. This route includes:
- **Start Point**: 40.67280, 14.76750
- **Turnaround Point**: 40.66900, 14.79700 (at 2.5km)
- **Finish Point**: 40.67280, 14.76750 (back to start)
- **Total Distance**: ~5km
- **Total Time**: ~21 minutes (simulated)

## How to Use

### 1. In the Run Screen
When you're on the Run screen, you'll see a **GPS Simulation Widget** at the bottom (only visible in debug mode). This widget allows you to:

- **Load GPX**: Load the Salerno 5km run route
- **Start Simulation**: Begin GPS coordinate simulation
- **Stop Simulation**: Pause the simulation
- **Reset**: Return to the start of the route

### 2. Simulation Details
- **Interval**: GPS coordinates are updated every 2 seconds
- **Waypoints**: 15 waypoints along the route
- **Real-time Updates**: Each waypoint triggers a position update
- **Progress Tracking**: Shows current waypoint and overall progress

### 3. Integration
The GPS simulation integrates with your existing running functionality:
- Position updates are logged to the console
- Can be connected to your progress monitor
- Simulates real GPS behavior for testing

## Custom Routes

To create your own GPS routes:

1. **Export from GPS Device**: Use a GPS watch, phone app, or online route planner
2. **GPX Format**: Ensure the file is in GPX 1.1 format
3. **Place in Assets**: Add your GPX file to the `assets/gps/` directory
4. **Update pubspec.yaml**: Make sure the file is included in assets
5. **Load in App**: Use the GPS simulation widget to load your custom route

## Technical Details

- **File Format**: GPX 1.1 (GPS Exchange Format)
- **Coordinate System**: WGS84 (standard GPS coordinates)
- **Timestamps**: Optional, will use current time if not provided
- **Waypoints**: Each `<wpt>` element represents a GPS position
- **Parsing**: Uses the `xml` package for GPX file parsing

## Debug Information

When running GPS simulation, check the console for:
- 🎯 GPS Simulation: Loading and parsing messages
- 🎯 GPS Simulation: Waypoint updates
- 🎯 GPS Simulation: Position updates
- 🎯 GPS Simulation: Simulation status

## Troubleshooting

- **File Not Found**: Ensure the GPX file is in the correct assets directory
- **Parse Errors**: Check that your GPX file follows the correct format
- **No Waypoints**: Verify the GPX file contains `<wpt>` elements
- **Coordinates Invalid**: Ensure latitude/longitude values are valid decimal degrees

## Example GPX Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1">
  <metadata>
    <name>Route Name</name>
    <desc>Route Description</desc>
  </metadata>
  
  <wpt lat="40.67280" lon="14.76750">
    <name>Start</name>
    <time>2025-08-17T08:00:00Z</time>
  </wpt>
  
  <!-- Add more waypoints as needed -->
</gpx>
```

This GPS simulation feature allows you to thoroughly test your running app's GPS functionality without needing to go outside or use real GPS hardware.







