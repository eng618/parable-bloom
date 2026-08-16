import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:parable_bloom/core/services/openpanel_analytics_client.dart";

void main() {
  group("OpenpanelAnalyticsClient", () {
    test("posts event payload and headers to configured endpoint", () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;
      late Map<String, dynamic> capturedBody;

      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"success":true}', 200);
      });

      final openpanel = OpenpanelAnalyticsClient(
        clientId: "test-client-id-123",
        endpoint: "https://openpanel.gventureshq.com/api/track",
        platform: "ios",
        client: client,
      );

      await openpanel.trackEvent(
        eventName: "level_complete",
        properties: {
          "level_id": "lvl_sprout_01",
          "taps_total": 12,
          "wrong_taps": 0,
        },
      );

      expect(
        capturedUri.toString(),
        "https://openpanel.gventureshq.com/api/track",
      );
      expect(capturedHeaders["openpanel-client-id"], "test-client-id-123");
      expect(capturedHeaders["Content-Type"], contains("application/json"));
      expect(capturedBody["name"], "level_complete");

      final props = capturedBody["properties"] as Map<String, dynamic>;
      expect(props["platform"], "ios");
      expect(props["level_id"], "lvl_sprout_01");
      expect(props["taps_total"], 12);
      expect(props["wrong_taps"], 0);
    });

    test("skips event submission when opted out", () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount += 1;
        return http.Response('{"success":true}', 200);
      });

      final openpanel = OpenpanelAnalyticsClient(
        clientId: "test-client-id-123",
        endpoint: "https://openpanel.gventureshq.com/api/track",
        client: client,
        isOptedOut: () => true,
      );

      await openpanel.trackEvent(eventName: "game_over");
      expect(callCount, 0);
    });

    test("normalizes API URL endpoint correctly", () {
      expect(
        OpenpanelAnalyticsClient.normalizeEndpoint(
          "https://openpanel.gventureshq.com/api",
        ),
        "https://openpanel.gventureshq.com/api/track",
      );
      expect(
        OpenpanelAnalyticsClient.normalizeEndpoint(
          "https://openpanel.gventureshq.com/api/",
        ),
        "https://openpanel.gventureshq.com/api/track",
      );
      expect(
        OpenpanelAnalyticsClient.normalizeEndpoint(
          "https://openpanel.gventureshq.com/api/track",
        ),
        "https://openpanel.gventureshq.com/api/track",
      );
    });

    test("resolves correct default client IDs per platform", () {
      expect(
        OpenpanelAnalyticsClient.resolveDefaultClientId("android"),
        OpenpanelAnalyticsClient.defaultAndroidClientId,
      );
      expect(
        OpenpanelAnalyticsClient.resolveDefaultClientId("ios"),
        OpenpanelAnalyticsClient.defaultIosClientId,
      );
      expect(
        OpenpanelAnalyticsClient.resolveDefaultClientId("web"),
        OpenpanelAnalyticsClient.defaultWebClientId,
      );
      expect(
        OpenpanelAnalyticsClient.resolveDefaultClientId("macos"),
        OpenpanelAnalyticsClient.defaultFallbackClientId,
      );
    });

    test("factory fromEnvironment sets default platform client ID", () {
      final client = OpenpanelAnalyticsClient.fromEnvironment(
        platform: "ios",
      );
      expect(client.clientId, OpenpanelAnalyticsClient.defaultIosClientId);
      expect(
        client.endpoint,
        "https://openpanel.gventureshq.com/api/track",
      );
      expect(client.platform, "ios");
    });
  });
}
