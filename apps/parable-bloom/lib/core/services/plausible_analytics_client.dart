import "dart:convert";

import "package:http/http.dart" as http;

import "logger_service.dart";

class PlausibleAnalyticsClient {
  static const String defaultDomain = "parable-bloom.web.app";
  static const String defaultEndpoint =
      "https://stats.garciaericn.com/api/event";
  static const String defaultPath = "/app";

  final String domain;
  final String endpoint;
  final String path;
  final http.Client _client;
  final bool Function() _isOptedOut;

  PlausibleAnalyticsClient({
    required this.domain,
    required this.endpoint,
    this.path = defaultPath,
    http.Client? client,
    bool Function()? isOptedOut,
  })  : _client = client ?? http.Client(),
        _isOptedOut = isOptedOut ?? _defaultOptOut;

  factory PlausibleAnalyticsClient.fromEnvironment({
    http.Client? client,
    bool Function()? isOptedOut,
  }) {
    final configuredDomain = const String.fromEnvironment(
      "NEXT_PUBLIC_PLAUSIBLE_DOMAIN",
      defaultValue: defaultDomain,
    );
    final configuredEndpoint = const String.fromEnvironment(
      "NEXT_PUBLIC_PLAUSIBLE_ENDPOINT",
      defaultValue: defaultEndpoint,
    );

    return PlausibleAnalyticsClient(
      domain: configuredDomain,
      endpoint: configuredEndpoint,
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
        "Plausible tracking skipped due to opt-out",
        tag: "PlausibleAnalytics",
      );
      return;
    }

    final uri = Uri.parse(endpoint);
    final eventPayload = {
      "name": eventName,
      "url": "https://$domain$path",
      "domain": domain,
      if (properties.isNotEmpty) "props": properties,
    };

    try {
      final response = await _client.post(
        uri,
        headers: const {
          "Content-Type": "application/json",
        },
        body: jsonEncode(eventPayload),
      );

      if (response.statusCode >= 400) {
        LoggerService.error(
          "Plausible event rejected with status ${response.statusCode}",
          tag: "PlausibleAnalytics",
        );
      }
    } catch (error, stackTrace) {
      LoggerService.error(
        "Plausible event submission failed",
        error: error,
        stackTrace: stackTrace,
        tag: "PlausibleAnalytics",
      );
    }
  }

  static bool _defaultOptOut() => false;
}
