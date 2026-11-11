import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppUpdatePlatform { android, ios }

class AppUpdateOffer {
  const AppUpdateOffer({required this.platform, required this.version});

  final AppUpdatePlatform platform;
  final String version;

  Uri get storeUri => Uri.parse(switch (platform) {
    AppUpdatePlatform.android =>
      'https://play.google.com/store/apps/details?id=kz.gradusy24.app',
    AppUpdatePlatform.ios => 'https://apps.apple.com/kz/app/id6473792920',
  });
}

class AppUpdateService {
  AppUpdateService({
    required AppUpdatePlatform? platform,
    required Future<String> Function() installedVersion,
    DateTime Function()? now,
    Future<bool> Function(Uri uri)? openUrl,
  }) : _platform = platform,
       _installedVersion = installedVersion,
       _now = now ?? DateTime.now,
       _openUrl =
           openUrl ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  factory AppUpdateService.production() => AppUpdateService(
    platform: kIsWeb
        ? null
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => AppUpdatePlatform.android,
            TargetPlatform.iOS => AppUpdatePlatform.ios,
            _ => null,
          },
    installedVersion: () async => (await PackageInfo.fromPlatform()).version,
  );

  static final _manifestUri = Uri.parse(
    'https://app.gradusy24.kz/app-update.json',
  );
  static final _versionPattern = RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$');
  final AppUpdatePlatform? _platform;
  final Future<String> Function() _installedVersion;
  final DateTime Function() _now;
  final Future<bool> Function(Uri uri) _openUrl;
  final _sessionDeadlines = <String, int>{};
  Future<AppUpdateOffer?>? _pending;

  Future<AppUpdateOffer?> check() {
    if (_platform == null) return Future.value();
    return _pending ??= _check()
        .timeout(const Duration(seconds: 5))
        .catchError((Object _) => null)
        .whenComplete(() => _pending = null);
  }

  Future<AppUpdateOffer?> _check() async {
    final installed = _parse(await _installedVersion());
    if (installed == null) return null;
    final response = await http.get(
      _manifestUri,
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) return null;
    final value = data[_platform!.name];
    if (value is! String) return null;
    final version = value.trim();
    final published = _parse(version);
    if (published == null || !_isNewer(published, installed)) return null;
    final offer = AppUpdateOffer(platform: _platform, version: version);
    final prefs = await SharedPreferences.getInstance();
    final key = _snoozeKey(offer);
    final stored = prefs.get(key);
    final now = _now().millisecondsSinceEpoch;
    if (now < (_sessionDeadlines[key] ?? 0) ||
        (stored is int && now < stored)) {
      return null;
    }
    return offer;
  }

  static List<BigInt>? _parse(String value) {
    final trimmed = value.trim();
    if (!_versionPattern.hasMatch(trimmed)) return null;
    return trimmed.split('.').map(BigInt.parse).toList(growable: false);
  }

  static bool _isNewer(List<BigInt> published, List<BigInt> installed) {
    for (var i = 0; i < 3; i++) {
      final order = published[i].compareTo(installed[i]);
      if (order != 0) return order > 0;
    }
    return false;
  }

  static String _snoozeKey(AppUpdateOffer offer) =>
      'app_update_snooze_${offer.platform.name}_${offer.version}';

  Future<bool> snooze(AppUpdateOffer offer) async {
    final key = _snoozeKey(offer);
    final deadline = _now()
        .add(const Duration(hours: 24))
        .millisecondsSinceEpoch;
    // Apply before any await: an unavailable store must not cause session nagging.
    _sessionDeadlines[key] = deadline;
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(key, deadline);
    } catch (_) {
      return false;
    }
  }

  Future<bool> openStore(AppUpdateOffer offer) async {
    try {
      return await _openUrl(offer.storeUri);
    } catch (_) {
      return false;
    }
  }
}
