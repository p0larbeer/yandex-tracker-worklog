import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/settings_repository.dart';
import 'holiday_transfers.dart';

/// Bundled asset + optional URL fetch + prefs cache.
class HolidayTransfersStore {
  HolidayTransfersStore({
    required SettingsRepository settingsRepository,
    http.Client? httpClient,
    this.assetPath = 'calendar/holiday_transfers.json',
  })  : _settings = settingsRepository,
        _http = httpClient ?? http.Client();

  final SettingsRepository _settings;
  final http.Client _http;
  final String assetPath;

  /// baked ← asset ← cache ← remote URL (если задан).
  Future<HolidayTransfers> resolve({String? url}) async {
    var result = HolidayTransfers.baked;

    try {
      final asset = await rootBundle.loadString(assetPath);
      result = result.mergeYearsFrom(HolidayTransfers.fromJsonString(asset));
    } catch (_) {}

    final cached = await _settings.loadHolidayTransfersCache();
    if (cached != null && cached.trim().isNotEmpty) {
      try {
        result = result.mergeYearsFrom(HolidayTransfers.fromJsonString(cached));
      } catch (_) {}
    }

    final remoteUrl = url?.trim() ?? '';
    if (remoteUrl.isNotEmpty) {
      try {
        final fetched = await fetchRemote(remoteUrl);
        await _settings.saveHolidayTransfersCache(jsonEncode(fetched.toJson()));
        result = result.mergeYearsFrom(fetched);
      } catch (_) {}
    }

    return result;
  }

  Future<HolidayTransfers> fetchRemote(String url) async {
    final response = await _http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('HTTP ${response.statusCode}');
    }
    return HolidayTransfers.fromJsonString(response.body);
  }

  /// Принудительно скачать URL, записать кэш, вернуть полный resolve без повторного GET.
  Future<HolidayTransfers> refreshFromUrl(String url) async {
    final fetched = await fetchRemote(url.trim());
    await _settings.saveHolidayTransfersCache(jsonEncode(fetched.toJson()));
    return resolve(url: '');
  }
}
