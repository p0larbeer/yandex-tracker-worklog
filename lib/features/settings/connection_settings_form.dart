import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_settings.dart';
import '../../core/config/settings_providers.dart';
import '../../services/tracker_api.dart';
import '../week/week_page.dart';
import 'tracker_setup_help.dart';

/// Форма подключения + проверка /myself.
class ConnectionSettingsForm extends ConsumerStatefulWidget {
  const ConnectionSettingsForm({
    super.key,
    required this.initial,
    this.isFirstRun = false,
  });

  final AppSettings initial;
  final bool isFirstRun;

  @override
  ConsumerState<ConnectionSettingsForm> createState() =>
      _ConnectionSettingsFormState();
}

class _ConnectionSettingsFormState
    extends ConsumerState<ConnectionSettingsForm> {
  late final TextEditingController _token;
  late final TextEditingController _orgId;
  late final TextEditingController _login;
  late final TextEditingController _queue;
  late final TextEditingController _norm;
  late final TextEditingController _orgJson;
  late bool _useCloudOrgId;
  late Set<int> _weekendWeekdays;
  late bool _useRussianHolidays;

  bool _obscureToken = true;
  bool _busy = false;
  String? _statusMessage;
  bool _statusOk = false;
  List<OrgIdCandidate> _orgCandidates = const [];

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _token = TextEditingController(text: s.oauthToken);
    _orgId = TextEditingController(text: s.orgId);
    _login = TextEditingController(text: s.login);
    _queue = TextEditingController(text: s.queuePrefix);
    _orgJson = TextEditingController();
    _norm = TextEditingController(
      text: s.dailyNormHours == s.dailyNormHours.roundToDouble()
          ? '${s.dailyNormHours.toInt()}'
          : '${s.dailyNormHours}',
    );
    _useCloudOrgId = s.useCloudOrgId;
    _weekendWeekdays = Set<int>.from(s.weekendWeekdays);
    _useRussianHolidays = s.useRussianHolidays;
  }

  @override
  void dispose() {
    _token.dispose();
    _orgId.dispose();
    _login.dispose();
    _queue.dispose();
    _norm.dispose();
    _orgJson.dispose();
    super.dispose();
  }

  void _parseOrgJson() {
    final candidates = extractOrgIdCandidates(_orgJson.text);
    setState(() {
      _orgCandidates = candidates;
      if (candidates.isEmpty) {
        _statusOk = false;
        _statusMessage =
            'Не удалось найти id в JSON. Нужен Response от getOrganizationInfo / '
            'getOrganizationFront / listOrganizations.';
      } else {
        _statusOk = true;
        _statusMessage =
            'Найдено кандидатов: ${candidates.length}. Выберите один ниже '
            '(для API нужный id может отличаться от полей в ответе UI).';
      }
    });
  }

  void _applyCandidate(OrgIdCandidate candidate) {
    setState(() {
      _orgId.text = candidate.value;
      _useCloudOrgId = candidate.preferCloudHeader;
      _statusOk = true;
      _statusMessage =
          'Подставлен ${candidate.source}=${candidate.value} '
          '(${candidate.preferCloudHeader ? 'X-Cloud-Org-ID' : 'X-Org-ID'}). '
          'Нажмите «Проверить подключение». Если ошибка — выберите другого кандидата.';
    });
  }

  AppSettings _draft() {
    final norm = double.tryParse(_norm.text.replaceAll(',', '.')) ?? 8;
    final weekends = _weekendWeekdays.isEmpty
        ? const {DateTime.saturday, DateTime.sunday}
        : Set<int>.from(_weekendWeekdays);
    return widget.initial.copyWith(
      oauthToken: _token.text.trim(),
      orgId: _orgId.text.trim(),
      useCloudOrgId: _useCloudOrgId,
      login: _login.text.trim(),
      queuePrefix: _queue.text.trim(),
      dailyNormHours: norm <= 0 ? 8 : norm,
      weekendWeekdays: weekends,
      useRussianHolidays: _useRussianHolidays,
    );
  }

  Future<void> _saveOnly() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final settings = _draft();
      if (!settings.hasApiCredentials) {
        setState(() {
          _statusOk = false;
          _statusMessage =
              'Нужны OAuth-токен и ID организации — без них API не заработает.';
        });
        return;
      }
      await ref.read(settingsProvider.notifier).save(settings);
      if (!mounted) return;
      setState(() {
        _statusOk = true;
        _statusMessage = settings.login.trim().isEmpty
            ? 'Сохранено. Нажмите «Проверить подключение», '
                'чтобы подставить логин и открыть неделю.'
            : 'Настройки сохранены.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAndCheck({required bool goToWeekOnSuccess}) async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final settings = _draft();
      if (!settings.hasApiCredentials) {
        setState(() {
          _statusOk = false;
          _statusMessage =
              'Заполните токен и ID организации, затем повторите проверку.';
        });
        return;
      }

      await ref.read(settingsProvider.notifier).save(settings);
      final myself = await ref.read(trackerApiProvider).fetchMyself(settings);

      var next = settings;
      if (next.login.isEmpty && myself.id.isNotEmpty) {
        next = next.copyWith(login: myself.id);
        _login.text = myself.id;
        await ref.read(settingsProvider.notifier).save(next);
      }

      if (!mounted) return;
      setState(() {
        _statusOk = true;
        _statusMessage =
            'Подключено: ${myself.display}'
            '${myself.email != null ? ' (${myself.email})' : ''}.';
      });

      if (goToWeekOnSuccess) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          WeekPage.routeName,
          (route) => false,
        );
      }
    } on TrackerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusOk = false;
        _statusMessage = e.userMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusOk = false;
        _statusMessage =
            'Сеть или локальная ошибка: $e. '
            'Проверьте интернет и proxy (api.tracker.yandex.net).';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.isFirstRun ? 'Данные подключения' : 'Параметры',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _token,
          obscureText: _obscureToken,
          decoration: InputDecoration(
            labelText: 'OAuth-токен *',
            hintText: 'y0_…',
            border: const OutlineInputBorder(),
            helperText: 'Хранится в защищённом хранилище ОС, не в файлах проекта',
            suffixIcon: IconButton(
              tooltip: _obscureToken ? 'Показать' : 'Скрыть',
              onPressed: () => setState(() => _obscureToken = !_obscureToken),
              icon: Icon(
                _obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _orgId,
          decoration: const InputDecoration(
            labelText: 'ID организации *',
            hintText: 'Значение для заголовка X-Org-ID или X-Cloud-Org-ID',
            border: OutlineInputBorder(),
            helperText:
                'Не название организации. Часто отличается от id в ответе UI.',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _orgJson,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Разобрать JSON организации (опционально)',
            hintText:
                'Вставьте Response из getOrganizationInfo / getOrganizationFront',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _parseOrgJson,
          icon: const Icon(Icons.data_object_outlined),
          label: const Text('Найти кандидатов ID в JSON'),
        ),
        if (_orgCandidates.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _orgCandidates)
                ActionChip(
                  label: Text(
                    '${c.source}: ${c.value}'
                    '${c.preferCloudHeader ? ' · Cloud' : ''}',
                  ),
                  onPressed: _busy ? null : () => _applyCandidate(c),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Организация Yandex Cloud / Identity Hub'),
          subtitle: Text(
            _useCloudOrgId
                ? 'Будет отправлен заголовок X-Cloud-Org-ID'
                : 'Будет отправлен заголовок X-Org-ID (Яндекс 360)',
          ),
          value: _useCloudOrgId,
          onChanged: _busy
              ? null
              : (v) => setState(() => _useCloudOrgId = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _login,
          decoration: const InputDecoration(
            labelText: 'Логин в Tracker',
            hintText: 'Можно заполнить автоматически после проверки',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _queue,
          decoration: const InputDecoration(
            labelText: 'Префикс очереди (опционально)',
            hintText: 'Ключ очереди, если нужен фильтр',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _norm,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Норма часов в день',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Выходные дни недели',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Отметьте дни, которые считаются нерабочими (по умолчанию сб и вс).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _weekdayLabels.entries)
              FilterChip(
                label: Text(entry.value),
                selected: _weekendWeekdays.contains(entry.key),
                onSelected: _busy
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected) {
                            _weekendWeekdays.add(entry.key);
                          } else {
                            _weekendWeekdays.remove(entry.key);
                          }
                        });
                      },
              ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Учитывать праздники РФ'),
          subtitle: const Text(
            'Ст. 112 ТК РФ и известные переносы (2025–2027). '
            'Праздник важнее обычного выходного в бейдже дня.',
          ),
          value: _useRussianHolidays,
          onChanged: _busy
              ? null
              : (v) => setState(() => _useRussianHolidays = v),
        ),
        const SizedBox(height: 16),
        if (_statusMessage != null) ...[
          Material(
            color: _statusOk
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _statusMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _statusOk
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _saveAndCheck(goToWeekOnSuccess: widget.isFirstRun),
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user_outlined),
          label: Text(
            widget.isFirstRun
                ? 'Проверить и продолжить'
                : 'Проверить подключение',
          ),
        ),
        const SizedBox(height: 8),
        if (!widget.isFirstRun)
          OutlinedButton.icon(
            onPressed: _busy ? null : _saveOnly,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Сохранить без проверки'),
          ),
      ],
    );
  }
}

const _weekdayLabels = <int, String>{
  DateTime.monday: 'Пн',
  DateTime.tuesday: 'Вт',
  DateTime.wednesday: 'Ср',
  DateTime.thursday: 'Чт',
  DateTime.friday: 'Пт',
  DateTime.saturday: 'Сб',
  DateTime.sunday: 'Вс',
};
