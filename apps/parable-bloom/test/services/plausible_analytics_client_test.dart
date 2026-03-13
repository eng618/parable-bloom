import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:parable_bloom/services/plausible_analytics_client.dart";

void main() {
  group("PlausibleAnalyticsClient", () {
    test("posts event payload to configured endpoint", () async {
      late Uri capturedUri;
      late Map<String, dynamic> capturedBody;

      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response("ok", 202);
      });

      final plausible = PlausibleAnalyticsClient(
        domain: "game.example.com",
        endpoint: "https://stats.example.com/api/event",
        client: client,
      );

      await plausible.trackEvent(
        eventName: "level_complete",
        properties: {
          "level_id": 7,
          "perfect": 1,
        },
      );

      expect(capturedUri.toString(), "https://stats.example.com/api/event");
      expect(capturedBody["name"], "level_complete");
      expect(capturedBody["domain"], "game.example.com");
      expect(capturedBody["url"], "https://game.example.com/app");
      expect(capturedBody["props"]["level_id"], 7);
      expect(capturedBody["props"]["perfect"], 1);
    });

    test("skips event submission when opted out", () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount += 1;
        return http.Response("ok", 202);
      });

      final plausible = PlausibleAnalyticsClient(
        domain: "game.example.com",
        endpoint: "https://stats.example.com/api/event",
        client: client,
        isOptedOut: () => true,
      );

      await plausible.trackEvent(eventName: "game_over");
      expect(callCount, 0);
    });
  });
}
