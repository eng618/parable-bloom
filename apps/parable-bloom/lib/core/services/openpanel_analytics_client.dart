import "dart:convert";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;

import "logger_service.dart";

class OpenpanelAnalyticsClient {
  static const String defaultAndroidClientId =
      "b4586d53-64e1-483a-b28b-e19916b29c9b";
  static const String defaultIosClientId =
      "01c5b484-f348-48c5-a67a-16d54a6423e0";
  static const String defaultWebClientId =
      "a6693179-1176-42f8-a1b8-b9a5196ab4e0";
  static const String defaultFallbackClientId =
      "57d65b3c-ceae-4dec-a729-8282740ba273";

  static const String defaultApiUrl = "https://openpanel.gventureshq.com/api";

  final String clientId;
  final String endpoint;
  final String platform;
  final http.Client _client;
  final bool Function() _isOptedOut;

  OpenpanelAnalyticsClient({
    required this.clientId,
    required this.endpoint,
    String? platform,
    http.Client? client,
    bool Function()? isOptedOut,
  })  : platform = platform ?? resolveCurrentPlatform(),
        _client = client ?? http.Client(),
        _isOptedOut = isOptedOut ?? _defaultOptOut;

  static String resolveCurrentPlatform() {
    if (kIsWeb) return "web";
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return "android";
      case TargetPlatform.iOS:
        return "ios";
      case TargetPlatform.macOS:
        return "macos";
      case TargetPlatform.windows:
        return "windows";
      case TargetPlatform.linux:
        return "linux";
      case TargetPlatform.fuchsia:
        return "fuchsia";
    }
  }

  static String resolveDefaultClientId([String? targetPlatform]) {
    final platform = targetPlatform ?? resolveCurrentPlatform();
    switch (platform) {
      case "android":
        return defaultAndroidClientId;
      case "ios":
        return defaultIosClientId;
      case "web":
        return defaultWebClientId;
      default:
        return defaultFallbackClientId;
    }
  }

  static String normalizeEndpoint(String rawUrl) {
    final trimmed = rawUrl.trim().replaceAll(RegExp(r"/+$"), "");
    if (trimmed.endsWith("/track")) {
      return trimmed;
    }
    return "$trimmed/track";
  }

  factory OpenpanelAnalyticsClient.fromEnvironment({
    http.Client? client,
    bool Function()? isOptedOut,
    String? platform,
  }) {
    final resolvedPlatform = platform ?? resolveCurrentPlatform();
    final defaultIdForPlatform = resolveDefaultClientId(resolvedPlatform);

    final configuredClientId = const String.fromEnvironment(
      "OPENPANEL_CLIENT_ID",
      defaultValue: "",
    );

    final clientId = configuredClientId.isNotEmpty
        ? configuredClientId
        : defaultIdForPlatform;

    final rawApiUrl = const String.fromEnvironment(
      "OPENPANEL_API_URL",
      defaultValue: defaultApiUrl,
    );

    final endpoint = normalizeEndpoint(rawApiUrl);

    return OpenpanelAnalyticsClient(
      clientId: clientId,
      endpoint: endpoint,
      platform: resolvedPlatform,
      client: client,
      isOptedOut: isOptedOut,
    );
  }

  Future<void> trackEvent({
    required String eventName,
    Map<String, Object?> properties = const {},
  }) async {
    if (_isOptedOut()) {
      LoggerService.debug(
        "Openpanel tracking skipped due to opt-out",
        tag: "OpenpanelAnalytics",
      );
      return;
    }

    final uri = Uri.parse(endpoint);
    final enrichedProps = <String, Object?>{
      "platform": platform,
      ...properties,
    };

    final eventPayload = {
      "name": eventName,
      "properties": enrichedProps,
    };

    try {
      final response = await _client.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "openpanel-client-id": clientId,
        },
        body: jsonEncode(eventPayload),
      );

      if (response.statusCode >= 400) {
        LoggerService.error(
          "Openpanel event rejected with status ${response.statusCode}",
          tag: "OpenpanelAnalytics",
        );
      }
    } catch (error, stackTrace) {
      LoggerService.error(
        "Openpanel event submission failed",
        error: error,
        stackTrace: stackTrace,
        tag: "OpenpanelAnalytics",
      );
    }
  }

  static bool _defaultOptOut() => false;
}
