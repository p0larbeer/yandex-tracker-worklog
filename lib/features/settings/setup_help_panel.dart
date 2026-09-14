import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/app_messenger.dart';
import 'tracker_setup_help.dart';

Future<void> openSetupUrl(String url) async {
  final uri = Uri.parse(url);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    throw Exception('Не удалось открыть $url');
  }
}

/// Пошаговая инструкция получения токена и Org ID.
class SetupHelpPanel extends StatelessWidget {
  const SetupHelpPanel({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Как получить доступ к API',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Если вы впервые подключаете Tracker — выполните шаги по порядку. '
          'Ссылки открываются в браузере.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(TrackerSetupHelp.steps.length, (index) {
          final step = TrackerSetupHelp.steps[index];
          return _StepTile(
            index: index + 1,
            step: step,
            dense: dense,
          );
        }),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.dense,
  });

  final int index;
  final SetupHelpStep step;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.only(bottom: dense ? 8 : 10),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(dense ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(
                    '$index',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(step.body, style: theme.textTheme.bodyMedium),
            if (step.url != null && step.linkLabel != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openSetupUrl(step.url!),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(step.linkLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Поле ClientID → кнопка открытия ссылки выдачи токена.
class ClientIdTokenHelper extends ConsumerStatefulWidget {
  const ClientIdTokenHelper({super.key});

  @override
  ConsumerState<ClientIdTokenHelper> createState() =>
      _ClientIdTokenHelperState();
}

class _ClientIdTokenHelperState extends ConsumerState<ClientIdTokenHelper> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openTokenPage() async {
    final messenger = ref.read(appMessengerProvider);
    final clientId = _controller.text.trim();
    if (clientId.isEmpty) {
      messenger.error('Сначала вставьте ClientID приложения');
      return;
    }
    final url = TrackerSetupHelp.tokenAuthorizeUrl(clientId);
    try {
      await openSetupUrl(url);
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      messenger.info('Не удалось открыть браузер. Ссылка скопирована:\n$url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'ClientID приложения (для ссылки на токен)',
            hintText: 'Вставьте ClientID из oauth.yandex.ru',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: _openTokenPage,
          icon: const Icon(Icons.key_outlined),
          label: const Text('Открыть страницу получения токена'),
        ),
      ],
    );
  }
}
