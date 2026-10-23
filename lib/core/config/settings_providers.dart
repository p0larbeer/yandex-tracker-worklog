import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'settings_repository.dart';
import '../calendar/holiday_transfers.dart';
import '../calendar/holiday_transfers_store.dart';
import '../../services/tracker_api.dart';
import '../../services/worklog_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final holidayTransfersStoreProvider = Provider<HolidayTransfersStore>((ref) {
  return HolidayTransfersStore(
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
});

/// Актуальные переносы: asset + cache + opt-in URL из настроек.
final holidayTransfersProvider =
    AsyncNotifierProvider<HolidayTransfersNotifier, HolidayTransfers>(
  HolidayTransfersNotifier.new,
);

class HolidayTransfersNotifier extends AsyncNotifier<HolidayTransfers> {
  @override
  Future<HolidayTransfers> build() async {
    final settings = await ref.watch(settingsProvider.future);
    return ref.read(holidayTransfersStoreProvider).resolve(
          url: settings.holidayTransfersUrl,
        );
  }

  Future<void> refreshFromConfiguredUrl() async {
    final settings = await ref.read(settingsProvider.future);
    final url = settings.holidayTransfersUrl.trim();
    if (url.isEmpty) {
      state = AsyncData(
        await ref.read(holidayTransfersStoreProvider).resolve(url: ''),
      );
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(holidayTransfersStoreProvider).refreshFromUrl(url);
    });
  }
}

final trackerApiProvider = Provider<TrackerApiClient>((ref) {
  return TrackerApiClient();
});

final worklogServiceProvider = Provider<WorklogService>((ref) {
  return WorklogService(ref.watch(trackerApiProvider));
});

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.read(settingsRepositoryProvider).load();
  }

  Future<void> save(AppSettings settings) async {
    // Без AsyncLoading: иначе home мигает спиннером, а week/day
    // на мгновение видят asData == null.
    await ref.read(settingsRepositoryProvider).save(settings);
    state = AsyncData(settings);
    ref.invalidate(holidayTransfersProvider);
  }
}
