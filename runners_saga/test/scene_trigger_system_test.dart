import 'package:flutter_test/flutter_test.dart';
import 'package:runners_saga/shared/services/story/scene_trigger_service.dart';

void main() {
  group('Scene Trigger System Tests', () {
    late SceneTriggerService sceneTrigger;

    setUp(() {
      sceneTrigger = SceneTriggerService();
    });

    tearDown(() {
      sceneTrigger.dispose();
    });

    test('Scene trigger percentages are correct', () {
      expect(SceneTriggerService.getSceneTriggerPercentage(SceneType.missionBriefing), equals(0.0));
      expect(SceneTriggerService.getSceneTriggerPercentage(SceneType.theJourney), equals(0.2));
      expect(SceneTriggerService.getSceneTriggerPercentage(SceneType.firstContact), equals(0.4));
      expect(SceneTriggerService.getSceneTriggerPercentage(SceneType.theCrisis), equals(0.7));
      expect(SceneTriggerService.getSceneTriggerPercentage(SceneType.extractionDebrief), equals(0.9));
    });

    test('Scene titles are correct', () {
      expect(SceneTriggerService.getSceneTitle(SceneType.missionBriefing), equals('Mission Briefing'));
      expect(SceneTriggerService.getSceneTitle(SceneType.theJourney), equals('The Journey'));
      expect(SceneTriggerService.getSceneTitle(SceneType.firstContact), equals('First Contact'));
      expect(SceneTriggerService.getSceneTitle(SceneType.theCrisis), equals('The Crisis'));
      expect(SceneTriggerService.getSceneTitle(SceneType.extractionDebrief), equals('Extraction & Debrief'));
    });

    test('Scene audio files are correct', () {
      expect(SceneTriggerService.getSceneAudioFile(SceneType.missionBriefing), equals('scene_1_mission_briefing.wav'));
      expect(SceneTriggerService.getSceneAudioFile(SceneType.theJourney), equals('scene_2_the_journey.wav'));
      expect(SceneTriggerService.getSceneAudioFile(SceneType.firstContact), equals('scene_3_first_contact.wav'));
      expect(SceneTriggerService.getSceneAudioFile(SceneType.theCrisis), equals('scene_4_the_crisis.wav'));
      expect(SceneTriggerService.getSceneAudioFile(SceneType.extractionDebrief), equals('scene_5_extraction_debrief.wav'));
    });

    test('Initialization sets correct targets', () {
      const targetTime = Duration(minutes: 15);
      const targetDistance = 5.0;

      sceneTrigger.initialize(
        targetTime: targetTime,
        targetDistance: targetDistance,
      );

      // Test that the service is ready to start
      expect(sceneTrigger.isRunning, isFalse);
    });

    test('Progress calculation works correctly', () {
      const targetTime = Duration(minutes: 15);
      const targetDistance = 5.0;

      sceneTrigger.initialize(
        targetTime: targetTime,
        targetDistance: targetDistance,
      );

      // Test 50% progress
      sceneTrigger.updateProgress(progress: 0.5);
      expect(sceneTrigger.currentProgress, equals(0.5));

      // Test 100% progress
      sceneTrigger.updateProgress(progress: 1.0);
      expect(sceneTrigger.currentProgress, equals(1.0));
    });

    test('Scene triggers at correct progress points', () {
      const targetTime = Duration(minutes: 15);
      const targetDistance = 5.0;

      sceneTrigger.initialize(
        targetTime: targetTime,
        targetDistance: targetDistance,
      );

      // Test that no scenes are played initially
      expect(sceneTrigger.playedScenes, isEmpty);

      // Test that mission briefing triggers at 0%
      sceneTrigger.updateProgress(progress: 0.0);
      expect(sceneTrigger.playedScenes, contains(SceneType.missionBriefing));

      // Test that journey triggers at 20%
      sceneTrigger.updateProgress(progress: 0.2);
      expect(sceneTrigger.playedScenes, contains(SceneType.theJourney));

      // Test that first contact triggers at 40%
      sceneTrigger.updateProgress(progress: 0.4);
      expect(sceneTrigger.playedScenes, contains(SceneType.firstContact));

      // Test that crisis triggers at 70%
      sceneTrigger.updateProgress(progress: 0.7);
      expect(sceneTrigger.playedScenes, contains(SceneType.theCrisis));

      // Test that extraction triggers at 90%
      sceneTrigger.updateProgress(progress: 0.9);
      expect(sceneTrigger.playedScenes, contains(SceneType.extractionDebrief));
    });

    test('Scenes do not repeat', () {
      const targetTime = Duration(minutes: 15);
      const targetDistance = 5.0;

      sceneTrigger.initialize(
        targetTime: targetTime,
        targetDistance: targetDistance,
      );

      // Trigger scenes multiple times
      sceneTrigger.updateProgress(progress: 0.0);
      sceneTrigger.updateProgress(progress: 0.0);
      sceneTrigger.updateProgress(progress: 0.2);
      sceneTrigger.updateProgress(progress: 0.2);

      // Should only have 2 scenes played
      expect(sceneTrigger.playedScenes.length, equals(2));
      expect(sceneTrigger.playedScenes, contains(SceneType.missionBriefing));
      expect(sceneTrigger.playedScenes, contains(SceneType.theJourney));
    });

    test('Service can be started and stopped', () {
      const targetTime = Duration(minutes: 15);
      const targetDistance = 5.0;

      sceneTrigger.initialize(
        targetTime: targetTime,
        targetDistance: targetDistance,
      );

      // Start the service
      sceneTrigger.start();
      expect(sceneTrigger.isRunning, isTrue);

      // Stop the service
      sceneTrigger.stop();
      expect(sceneTrigger.isRunning, isFalse);
      expect(sceneTrigger.playedScenes, isEmpty);
    });

    test('Service can be paused and resumed', () {
      const targetTime = Duration(minutes: 15);
      const targetDistance = 5.0;

      sceneTrigger.initialize(
        targetTime: targetTime,
        targetDistance: targetDistance,
      );

      // Start the service
      sceneTrigger.start();
      expect(sceneTrigger.isRunning, isTrue);

      // Pause the service
      sceneTrigger.pause();
      expect(sceneTrigger.isRunning, isFalse);

      // Resume the service
      sceneTrigger.resume();
      expect(sceneTrigger.isRunning, isTrue);
    });
  });
}


