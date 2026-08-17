import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:parable_bloom/core/services/analytics_service.dart";
import "package:parable_bloom/core/services/openpanel_analytics_client.dart";

void main() {
  group("AnalyticsService with Openpanel dual tracking", () {
    late List<Map<String, dynamic>> trackedPayloads;
    late AnalyticsService service;

    setUp(() {
      trackedPayloads = [];
      final mockClient = MockClient((request) async {
        trackedPayloads.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{"status":"ok"}', 200);
      });

      final openpanelClient = OpenpanelAnalyticsClient(
        clientId: "test-client-id",
        endpoint: "https://openpanel.gventureshq.com/api/track",
        platform: "ios",
        client: mockClient,
      );

      service = AnalyticsService(openpanelClient: openpanelClient);
    });

    test("logs tutorial lifecycle events", () async {
      await service.logTutorialStart(source: "first_launch");
      await service.logTutorialStepComplete(
        stepNumber: 1,
        stepId: "lesson_1",
        elapsedSeconds: 15,
      );
      await service.logTutorialComplete(totalSeconds: 65);

      expect(trackedPayloads.length, 3);
      expect(trackedPayloads[0]["type"], "track");
      expect(trackedPayloads[0]["payload"]["name"], "tutorial_start");
      expect(trackedPayloads[0]["payload"]["properties"]["source"],
          "first_launch");

      expect(trackedPayloads[1]["type"], "track");
      expect(trackedPayloads[1]["payload"]["name"], "tutorial_step_complete");
      expect(trackedPayloads[1]["payload"]["properties"]["step_number"], 1);

      expect(trackedPayloads[2]["type"], "track");
      expect(trackedPayloads[2]["payload"]["name"], "tutorial_complete");
      expect(trackedPayloads[2]["payload"]["properties"]["total_seconds"], 65);
    });

    test("logs scripture and journal engagement", () async {
      await service.logScriptureUnlocked(
        scriptureId: "sc_matthew_13_1",
        reference: "Matthew 13:1-9",
        parableId: "parable_1",
      );
      await service.logScriptureRead(
        scriptureId: "sc_matthew_13_1",
        reference: "Matthew 13:1-9",
        translation: "WEB",
        durationSeconds: 22,
      );
      await service.logTranslationChanged(
        previousTranslation: "KJV",
        newTranslation: "WEB",
      );

      expect(trackedPayloads.length, 3);
      expect(trackedPayloads[0]["payload"]["name"], "scripture_unlocked");
      expect(trackedPayloads[1]["payload"]["name"], "scripture_read");
      expect(trackedPayloads[1]["payload"]["properties"]["translation"], "WEB");
      expect(trackedPayloads[2]["payload"]["name"], "translation_changed");
    });

    test("logs level quit and restart", () async {
      await service.logLevelQuit(
        levelId: "lvl_sprout_05",
        elapsedSeconds: 40,
        taps: 8,
        remainingVines: 3,
      );
      await service.logLevelRestart(
        "lvl_sprout_05",
        2,
        elapsedSeconds: 18,
      );

      expect(trackedPayloads.length, 2);
      expect(trackedPayloads[0]["payload"]["name"], "level_quit");
      expect(trackedPayloads[0]["payload"]["properties"]["level_id"],
          "lvl_sprout_05");
      expect(trackedPayloads[0]["payload"]["properties"]["remaining_vines"], 3);

      expect(trackedPayloads[1]["payload"]["name"], "level_restart");
      expect(trackedPayloads[1]["payload"]["properties"]["attempts"], 2);
    });

    test("logs auth actions and settings toggles", () async {
      await service.logAuthAction(
        action: "sign_up",
        success: true,
      );
      await service.logSettingChanged(
        settingName: "haptics",
        value: true,
      );

      expect(trackedPayloads.length, 2);
      expect(trackedPayloads[0]["payload"]["name"], "auth_action");
      expect(trackedPayloads[0]["payload"]["properties"]["action"], "sign_up");
      expect(trackedPayloads[1]["payload"]["name"], "setting_changed");
      expect(trackedPayloads[1]["payload"]["properties"]["setting_name"],
          "haptics");
    });
  });
}
