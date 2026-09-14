import 'package:flutter/material.dart';

/// Пояснение: где хранятся данные и куда они уходят по сети.
class LocalDataPrivacyBanner extends StatelessWidget {
  const LocalDataPrivacyBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Данные остаются на этом компьютере',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Токен — в защищённом хранилище ОС (Keychain / Credential Manager / '
                    'libsecret). Остальные настройки — локально на устройстве.\n'
                    'Отдельного сервера приложения нет: мы никуда не «отправляем» '
                    'ваши данные на свой бэкенд.\n'
                    'В интернет уходят только запросы к официальному API '
                    'Yandex Tracker (api.tracker.yandex.net) от вашего имени.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
