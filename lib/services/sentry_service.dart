import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'diagnostics_consent_service.dart';

class SentryService {
  static const String _defaultDsn = 'https://d19c02e97e5b55f26c69d3cbd7ad8394@o4510957798883328.ingest.us.sentry.io/4511133765271552';
  static const String _dsnOverride = String.fromEnvironment('SENTRY_DSN');
  static final String _dsn = _dsnOverride.trim().isNotEmpty ? _dsnOverride.trim() : _defaultDsn;
  static const String _environment = String.fromEnvironment('SENTRY_ENVIRONMENT');
  static const String _release = String.fromEnvironment('SENTRY_RELEASE');
  static const String _dist = String.fromEnvironment('SENTRY_DIST');
  static const String _tracesSampleRateValue = String.fromEnvironment('SENTRY_TRACES_SAMPLE_RATE', defaultValue: '0.2');
  static const String _profilesSampleRateValue = String.fromEnvironment('SENTRY_PROFILES_SAMPLE_RATE', defaultValue: '0.0');

  static bool _isInitializing = false;
  static PackageInfo? _packageInfo;

  static bool get hasConfiguredDsn => _dsn.trim().isNotEmpty;

  static final SentryNavigatorObserver navigatorObserver = SentryNavigatorObserver(
    routeNameExtractor: _extractRouteSettings,
    ignoreRoutes: const ['_dialog', '_modal_bottom_sheet'],
  );

  static Future<bool> initialize({AppRunner? appRunner, required String consentSource}) async {
    if (Sentry.isEnabled) {
      await _syncAnonymousScope(consentSource: consentSource);
      return true;
    }

    if (_isInitializing || !hasConfiguredDsn) {
      return false;
    }

    _isInitializing = true;

    try {
      await SentryFlutter.init((options) async {
        final packageInfo = await _getPackageInfo();

        options.dsn = _dsn;
        options.environment = _environment.isNotEmpty ? _environment : _resolveEnvironment();

        final release = _release.isNotEmpty ? _release : _buildRelease(packageInfo);
        if (release != null && release.isNotEmpty) {
          options.release = release;
        }

        final dist = _dist.isNotEmpty ? _dist : _buildDist(packageInfo);
        if (dist != null && dist.isNotEmpty) {
          options.dist = dist;
        }

        options.sendDefaultPii = false;
        options.attachScreenshot = false;
        options.attachViewHierarchy = false;
        options.enableUserInteractionTracing = false;
        options.enableAutoPerformanceTracing = true;
        options.tracesSampleRate = _normalizeSampleRate(_parseSampleRate(_tracesSampleRateValue, fallback: 0.2));
        options.profilesSampleRate = _normalizeSampleRate(_parseSampleRate(_profilesSampleRateValue, fallback: 0.0));
        options.maxRequestBodySize = MaxRequestBodySize.never;
        options.beforeSend = _beforeSend;
        options.beforeBreadcrumb = _beforeBreadcrumb;
      }, appRunner: appRunner);

      await _syncAnonymousScope(consentSource: consentSource);
      return Sentry.isEnabled;
    } finally {
      _isInitializing = false;
    }
  }

  static Future<bool> updateConsent(bool enabled, {required String source, bool persistChoice = true}) async {
    if (persistChoice) {
      await DiagnosticsConsentService.setDiagnosticsEnabled(enabled);
    }

    if (!enabled) {
      if (Sentry.isEnabled) {
        await Sentry.close();
      }
      return false;
    }

    if (!hasConfiguredDsn) {
      return false;
    }

    return initialize(consentSource: source);
  }

  static Future<void> addBreadcrumb({
    required String category,
    required String message,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.info,
    String type = 'default',
  }) async {
    if (!Sentry.isEnabled) {
      return;
    }

    await Sentry.addBreadcrumb(
      Breadcrumb(category: category, message: _sanitizeText(message), data: _sanitizeDynamicMap(data), level: level, type: type),
    );
  }

  static Future<void> captureBusinessFailure({
    required String message,
    required String category,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    SentryLevel level = SentryLevel.error,
  }) async {
    if (!Sentry.isEnabled) {
      return;
    }

    await Sentry.captureMessage(
      _sanitizeText(message),
      level: level,
      withScope: (scope) async {
        await scope.addBreadcrumb(
          Breadcrumb(category: category, message: _sanitizeText(message), data: _sanitizeDynamicMap(extra), level: level, type: 'error'),
        );
        await _applyScopeMetadata(scope, tags: tags, extra: extra);
      },
    );
  }

  static Future<void> captureHandledException(
    Object exception,
    StackTrace stackTrace, {
    required String message,
    required String category,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
  }) async {
    if (!Sentry.isEnabled) {
      return;
    }

    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) async {
        await scope.addBreadcrumb(
          Breadcrumb(category: category, message: _sanitizeText(message), data: _sanitizeDynamicMap(extra), level: SentryLevel.error, type: 'error'),
        );
        await _applyScopeMetadata(scope, tags: tags, extra: extra);
      },
    );
  }

  static Future<T> traceOperation<T>({
    required String name,
    required String operation,
    required Future<T> Function(ISentrySpan span) action,
    Map<String, String>? tags,
    Map<String, dynamic>? data,
    SpanStatus successStatus = const SpanStatus.ok(),
    SpanStatus failureStatus = const SpanStatus.internalError(),
  }) async {
    final span = Sentry.startTransaction(name, operation, bindToScope: false);
    _applySpanMetadata(span, tags: tags, data: data);

    final startedAt = DateTime.now();
    try {
      final result = await action(span);
      span.setData('duration_ms', DateTime.now().difference(startedAt).inMilliseconds);
      if (!span.finished) {
        await span.finish(status: span.status ?? successStatus);
      }
      return result;
    } catch (exception, stackTrace) {
      span.throwable = exception;
      span.setData('duration_ms', DateTime.now().difference(startedAt).inMilliseconds);
      if (!span.finished) {
        await span.finish(status: failureStatus);
      }
      await captureHandledException(exception, stackTrace, message: name, category: operation, tags: tags, extra: data);
      rethrow;
    }
  }

  static Future<void> syncAuthState({required bool isAuthenticated}) async {
    if (!Sentry.isEnabled) {
      return;
    }

    await Sentry.configureScope((scope) async {
      await scope.setUser(null);
      scope.setTag('auth_state', isAuthenticated ? 'authenticated' : 'guest');
    });
  }

  static Future<void> _syncAnonymousScope({required String consentSource}) async {
    if (!Sentry.isEnabled) {
      return;
    }

    await Sentry.configureScope((scope) async {
      await scope.setUser(null);
      scope.setTag('privacy_mode', 'anonymous_only');
      scope.setTag('diagnostics_consent', 'granted');
      scope.setTag('consent_source', consentSource);
    });
  }

  static RouteSettings? _extractRouteSettings(RouteSettings? settings) {
    if (settings == null) {
      return const RouteSettings(name: 'unknown');
    }

    final routeName = settings.name;
    if (routeName == null || routeName.isEmpty) {
      return const RouteSettings(name: 'unnamed');
    }

    return RouteSettings(name: _sanitizeText(routeName));
  }

  static void _applySpanMetadata(ISentrySpan span, {Map<String, String>? tags, Map<String, dynamic>? data}) {
    final sanitizedTags = _sanitizeStringMap(tags);
    if (sanitizedTags != null) {
      for (final entry in sanitizedTags.entries) {
        span.setTag(entry.key, entry.value);
      }
    }

    final sanitizedData = _sanitizeDynamicMap(data);
    if (sanitizedData != null) {
      for (final entry in sanitizedData.entries) {
        span.setData(entry.key, entry.value);
      }
    }
  }

  static Future<void> _applyScopeMetadata(Scope scope, {Map<String, String>? tags, Map<String, dynamic>? extra}) async {
    final sanitizedTags = _sanitizeStringMap(tags);
    if (sanitizedTags != null) {
      for (final entry in sanitizedTags.entries) {
        await scope.setTag(entry.key, entry.value);
      }
    }

    final sanitizedExtra = _sanitizeDynamicMap(extra);
    if (sanitizedExtra != null) {
      await scope.setContexts('custom_metadata', sanitizedExtra);
    }
  }

  static FutureOr<SentryEvent?> _beforeSend(SentryEvent event, Hint hint) {
    return SentryEvent(
      eventId: event.eventId,
      timestamp: event.timestamp,
      platform: event.platform,
      logger: event.logger,
      serverName: event.serverName,
      release: event.release,
      dist: event.dist,
      environment: event.environment,
      modules: event.modules,
      message: event.message,
      transaction: event.transaction == null ? null : _sanitizeText(event.transaction!),
      throwable: event.throwableMechanism,
      level: event.level,
      culprit: event.culprit == null ? null : _sanitizeText(event.culprit!),
      tags: _sanitizeStringMap(event.tags),
      fingerprint: event.fingerprint,
      user: null,
      contexts: Contexts.fromJson(event.contexts.toJson()),
      breadcrumbs: event.breadcrumbs?.map(_sanitizeBreadcrumb).whereType<Breadcrumb>().toList(growable: false),
      sdk: event.sdk,
      request: _sanitizeRequest(event.request),
      debugMeta: event.debugMeta,
      exceptions: event.exceptions,
      threads: event.threads,
      type: event.type,
    );
  }

  static Breadcrumb? _beforeBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
    if (breadcrumb == null) {
      return null;
    }

    final category = breadcrumb.category?.toLowerCase();
    if (category != null && category.contains('http')) {
      return null;
    }

    return _sanitizeBreadcrumb(breadcrumb);
  }

  static Breadcrumb? _sanitizeBreadcrumb(Breadcrumb breadcrumb) {
    return Breadcrumb(
      message: breadcrumb.message == null ? null : _sanitizeText(breadcrumb.message!),
      timestamp: breadcrumb.timestamp,
      category: breadcrumb.category,
      data: _sanitizeDynamicMap(breadcrumb.data),
      level: breadcrumb.level,
      type: breadcrumb.type,
    );
  }

  static SentryRequest? _sanitizeRequest(SentryRequest? request) {
    if (request == null) {
      return null;
    }

    return SentryRequest(
      url: _sanitizeUrl(request.url),
      method: request.method,
      apiTarget: request.apiTarget == null ? null : _sanitizeText(request.apiTarget!),
    );
  }

  static Map<String, String>? _sanitizeStringMap(Map<String, String>? source) {
    if (source == null || source.isEmpty) {
      return source;
    }

    final sanitized = <String, String>{};
    for (final entry in source.entries) {
      if (_isSensitiveKey(entry.key)) {
        sanitized[entry.key] = '[redacted]';
      } else {
        sanitized[entry.key] = _sanitizeText(entry.value);
      }
    }
    return sanitized;
  }

  static Map<String, dynamic>? _sanitizeDynamicMap(Map<String, dynamic>? source) {
    if (source == null || source.isEmpty) {
      return source;
    }

    final sanitized = <String, dynamic>{};
    for (final entry in source.entries) {
      sanitized[entry.key] = _sanitizeDynamicValue(entry.value, key: entry.key);
    }
    return sanitized;
  }

  static dynamic _sanitizeDynamicValue(dynamic value, {String? key}) {
    if (key != null && _isSensitiveKey(key)) {
      return '[redacted]';
    }

    if (value is String) {
      return _sanitizeText(value);
    }

    if (value is Map<String, dynamic>) {
      return _sanitizeDynamicMap(value);
    }

    if (value is Map) {
      return value.map((dynamic mapKey, dynamic mapValue) => MapEntry(mapKey.toString(), _sanitizeDynamicValue(mapValue, key: mapKey.toString())));
    }

    if (value is Iterable) {
      return value.map((item) => _sanitizeDynamicValue(item, key: key)).toList(growable: false);
    }

    return value;
  }

  static String? _sanitizeUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) {
      return rawUrl;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return _sanitizeText(rawUrl);
    }

    final sanitizedSegments = uri.pathSegments
        .map((segment) {
          if (_looksSensitivePathSegment(segment)) {
            return '[redacted]';
          }
          return _sanitizeText(segment);
        })
        .toList(growable: false);

    return Uri(
      scheme: uri.scheme.isEmpty ? null : uri.scheme,
      host: uri.host.isEmpty ? null : uri.host,
      port: uri.hasPort ? uri.port : null,
      pathSegments: sanitizedSegments,
    ).toString();
  }

  static bool _looksSensitivePathSegment(String segment) {
    if (segment.isEmpty) {
      return false;
    }

    if (_isSensitiveKey(segment)) {
      return true;
    }

    final hasLongDigits = RegExp(r'\d{4,}').hasMatch(segment);
    final looksLikeToken = RegExp(r'^[A-Za-z0-9_-]{24,}$').hasMatch(segment);
    final looksLikeUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(segment);

    return hasLongDigits || looksLikeToken || looksLikeUuid;
  }

  static bool _isSensitiveKey(String key) {
    return RegExp(
      r'(address|apartment|comment|cookie|email|entrance|floor|lat|latitude|login|lon|lng|longitude|name|password|phone|session|token|user|card|mask|ip|geo|auth)',
      caseSensitive: false,
    ).hasMatch(key);
  }

  static String _sanitizeText(String value) {
    var sanitized = value;
    sanitized = sanitized.replaceAll(RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false), '[redacted-email]');
    sanitized = sanitized.replaceAll(RegExp(r'(\+?\d[\d\s\-()]{8,}\d)'), '[redacted-phone]');
    sanitized = sanitized.replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), '[redacted-ip]');
    sanitized = sanitized.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._\-]+', caseSensitive: false), 'Bearer [redacted-token]');
    return sanitized;
  }

  static double _normalizeSampleRate(double value) {
    if (value < 0) {
      return 0.0;
    }
    if (value > 1) {
      return 1.0;
    }
    return value;
  }

  static double _parseSampleRate(String value, {required double fallback}) {
    return double.tryParse(value) ?? fallback;
  }

  static Future<PackageInfo?> _getPackageInfo() async {
    if (_packageInfo != null) {
      return _packageInfo;
    }

    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      _packageInfo = null;
    }

    return _packageInfo;
  }

  static String _resolveEnvironment() {
    if (kReleaseMode) {
      return 'release';
    }
    if (kProfileMode) {
      return 'profile';
    }
    return 'debug';
  }

  static String? _buildRelease(PackageInfo? packageInfo) {
    if (packageInfo == null || packageInfo.version.trim().isEmpty) {
      return null;
    }

    final version = packageInfo.version.trim();
    final buildNumber = packageInfo.buildNumber.trim();
    final releaseVersion = buildNumber.isEmpty ? version : '$version+$buildNumber';
    final packageName = packageInfo.packageName.trim();

    return packageName.isEmpty ? releaseVersion : '$packageName@$releaseVersion';
  }

  static String? _buildDist(PackageInfo? packageInfo) {
    if (packageInfo == null || packageInfo.buildNumber.trim().isEmpty) {
      return null;
    }

    return packageInfo.buildNumber.trim();
  }
}
