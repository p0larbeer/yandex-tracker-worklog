import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'settings_repository.dart';
import '../../services/tracker_api.dart';
import '../../services/worklog_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

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
  }
}
