import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/api_error_pane.dart';
import '../../core/ui/app_messenger.dart';
import '../../services/tracker_api.dart';
import '../settings/settings_page.dart';
import '../week/week_providers.dart';
import 'day_providers.dart';
import 'log_form_page.dart';
import 'widgets/day_body.dart';

/// Экран дня: список списаний + CRUD.
class DayPage extends ConsumerWidget {
  const DayPage({super.key, required this.day});

  final DateTime day;

  static Future<void> open(BuildContext context, WidgetRef ref, DateTime day) {
    ref.read(selectedDayProvider.notifier).setDay(day);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DayPage(day: day)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayAsync = ref.watch(dayWorklogProvider);
    final label = formatDayTitle(day);

    ref.listen(dayWorklogProvider, (previous, next) {
      if (previous?.isLoading != true) return;
      if (next.hasError) {
        ref.read(appMessengerProvider).error(dayErrorMessage(next.error!));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(label),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: dayAsync.isLoading
                ? null
                : () {
                    ref.read(appMessengerProvider).info('Обновляю день…');
                    invalidateWorklogViews(ref);
                  },
            icon: dayAsync.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LogFormPage(day: day),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Списание'),
      ),
      body: Column(
        children: [
          if (dayAsync.isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: dayAsync.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => ApiErrorPane(
                message: dayErrorMessage(e),
                emphasizeSettings: errorSuggestsOpenSettings(e),
                onRetry: () => ref.invalidate(dayWorklogProvider),
                onSettings: () {
                  Navigator.of(context).pushNamed(SettingsPage.routeName);
                },
              ),
              data: (data) => DayBody(data: data),
            ),
          ),
        ],
      ),
    );
  }
}
