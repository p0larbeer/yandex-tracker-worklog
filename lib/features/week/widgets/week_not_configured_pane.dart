import 'package:flutter/material.dart';

import '../../settings/setup_page.dart';

/// Заглушка недели, пока нет token/org/login.
class WeekNotConfiguredPane extends StatelessWidget {
  const WeekNotConfiguredPane({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.link_off,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Подключение не настроено',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Укажите токен и ID организации — затем здесь появится ваша неделя списаний.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(SetupPage.routeName);
                },
                child: const Text('Настроить подключение'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
