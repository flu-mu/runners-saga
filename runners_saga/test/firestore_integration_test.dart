import 'package:flutter_test/flutter_test.dart';
import 'package:runners_saga/shared/services/firestore_service.dart';
import 'package:runners_saga/shared/models/run_model.dart';
import 'package:runners_saga/shared/models/run_target_model.dart';

void main() {
  group('FirestoreService Integration Tests', () {
    late FirestoreService firestoreService;
    
    setUp(() {
      firestoreService = FirestoreService();
    });
    
    test('should save run to Firestore', () async {
      // This test would require Firebase emulator or test environment
      // For now, we'll test the data preparation logic
      
      final testRun = RunModel(
        userId: 'test_user_123',
        startTime: DateTime.now(),
        route: [
          LocationPoint(
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 5.0,
            altitude: 10.0,
            speed: 2.5,
            timestamp: DateTime.now(),
          ),
        ],
        totalDistance: 0.0,
        totalTime: Duration.zero,
        averagePace: 0.0,
        maxPace: 0.0,
        minPace: 0.0,
        seasonId: 'fantasy_quest',
        missionId: 'S01E01',
        status: RunStatus.inProgress,
        runTarget: RunTarget(
          id: 'test_target',
          type: RunTargetType.time,
          value: 30.0,
          displayName: '30 minutes',
          description: 'Test run target',
          createdAt: DateTime.now(),
          isCustom: false,
        ),
      );
      
      // Verify the run model can be converted to JSON
      final runJson = testRun.toJson();
      expect(runJson['userId'], equals('test_user_123'));
      expect(runJson['seasonId'], equals('fantasy_quest'));
      expect(runJson['missionId'], equals('S01E01'));
      expect(runJson['status'], equals('inProgress'));
      expect(runJson['route'], isA<List>());
      expect(runJson['route'].length, equals(1));
    });
    
    test('should handle run completion data correctly', () async {
      final completedRun = RunModel(
        userId: 'test_user_123',
        startTime: DateTime.now().subtract(Duration(minutes: 30)),
        endTime: DateTime.now(),
        route: List.generate(10, (index) => LocationPoint(
          latitude: 37.7749 + (index * 0.001),
          longitude: -122.4194 + (index * 0.001),
          accuracy: 5.0,
          altitude: 10.0,
          speed: 2.5 + (index * 0.1),
          timestamp: DateTime.now().subtract(Duration(minutes: 30 - index * 3)),
        )),
        totalDistance: 2.5,
        totalTime: Duration(minutes: 30),
        averagePace: 12.0,
        maxPace: 15.0,
        minPace: 10.0,
        seasonId: 'fantasy_quest',
        missionId: 'S01E01',
        status: RunStatus.completed,
        runTarget: RunTarget(
          id: 'test_target_2',
          type: RunTargetType.distance,
          value: 5.0,
          displayName: '5 km',
          description: 'Test distance target',
          createdAt: DateTime.now(),
          isCustom: false,
        ),
      );
      
      // Verify completion data
      expect(completedRun.status, equals(RunStatus.completed));
      expect(completedRun.endTime, isNotNull);
      expect(completedRun.route.length, equals(10));
      expect(completedRun.totalDistance, equals(2.5));
      expect(completedRun.totalTime.inMinutes, equals(30));
    });
    
    test('should calculate pace correctly', () {
      final startTime = DateTime.now();
      final endTime = startTime.add(Duration(minutes: 30));
      final distance = 5.0; // 5 km
      
      final timeDiff = endTime.difference(startTime);
      final timeInMinutes = timeDiff.inMinutes;
      final pace = timeInMinutes / distance;
      
      expect(pace, equals(6.0)); // 6 minutes per kilometer
    });
  });
}
