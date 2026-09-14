import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/settings_providers.dart';
import '../../core/ui/api_error_pane.dart';
import '../../core/ui/app_messenger.dart';
import '../../services/tracker_api.dart';
import '../day/day_providers.dart';
import '../settings/settings_page.dart';
import 'week_providers.dart';
import 'widgets/week_body.dart';
import 'widgets/week_header.dart';
import 'widgets/week_not_configured_pane.dart';

/// Экран «Неделя»: суммы по дням (поле start) и контроль нормы.
class WeekPage extends ConsumerWidget {
  const WeekPage({super.key});

  static const String routeName = '/week';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).asData?.value;
    final configured = settings?.isConfigured ?? false;
    final weekAsync = ref.watch(weekWorklogProvider);
    final monday = ref.watch(weekAnchorProvider);
    final sunday = monday.add(const Duration(days: 6));
    final showRefreshSpinner = weekAsync.isLoading;

    ref.listen(weekWorklogProvider, (previous, next) {
      if (previous?.isLoading != true) return;
      final messenger = ref.read(appMessengerProvider);
      if (next.hasError) {
        messenger.error(weekErrorMessage(next.error!));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Неделя'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: !configured || weekAsync.isLoading
                ? null
                : () async {
                    ref
                        .read(appMessengerProvider)
                        .info('Обновляю данные из Tracker…');
                    invalidateWorklogViews(ref);
                    try {
                      await ref.read(weekWorklogProvider.future);
                      ref.read(appMessengerProvider).success('Неделя обновлена');
                    } catch (_) {
                      // ошибка уже через listen
                    }
                  },
            icon: showRefreshSpinner
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed(SettingsPage.routeName);
            },
          ),
        ],
      ),
      body: !configured
          ? const WeekNotConfiguredPane()
          : Column(
              children: [
                if (weekAsync.isLoading)
                  const LinearProgressIndicator(minHeight: 2),
                WeekHeader(
                  label: formatWeekRange(monday, sunday),
                  onPrev: weekAsync.isLoading
                      ? null
                      : () {
                          ref.read(weekAnchorProvider.notifier).shiftWeeks(-1);
                        },
                  onNext: weekAsync.isLoading
                      ? null
                      : () {
                          ref.read(weekAnchorProvider.notifier).shiftWeeks(1);
                        },
                  onToday: weekAsync.isLoading
                      ? null
                      : () {
                          ref.read(weekAnchorProvider.notifier).goToToday();
                        },
                ),
                Expanded(
                  child: weekAsync.when(
                    skipLoadingOnReload: true,
                    skipLoadingOnRefresh: true,
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ApiErrorPane(
                      message: weekErrorMessage(e),
                      emphasizeSettings: errorSuggestsOpenSettings(e),
                      onRetry: () => ref.invalidate(weekWorklogProvider),
                      onSettings: () {
                        Navigator.of(context)
                            .pushNamed(SettingsPage.routeName);
                      },
                    ),
                    data: (data) => WeekBody(data: data),
                  ),
                ),
              ],
            ),
    );
  }
}
