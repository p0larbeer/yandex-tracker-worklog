import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/settings_providers.dart';
import '../../core/ui/app_messenger.dart';
import '../../core/utils/human_duration.dart';
import '../../core/utils/iso_duration.dart';
import '../../models/worklog_entry.dart';
import '../../services/tracker_api.dart';
import '../worklog/worklog_pending.dart';
import 'widgets/issue_autocomplete_field.dart';
import 'worklog_start.dart';

/// Форма создания / редактирования worklog.
class LogFormPage extends ConsumerStatefulWidget {
  const LogFormPage({
    super.key,
    required this.day,
    this.existing,
  });

  final DateTime day;
  final WorklogEntry? existing;

  @override
  ConsumerState<LogFormPage> createState() => _LogFormPageState();
}

class _LogFormPageState extends ConsumerState<LogFormPage> {
  late final TextEditingController _issue;
  late final TextEditingController _duration;
  late final TextEditingController _comment;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _issue = TextEditingController(text: e?.issue.key ?? '');
    if (e != null) {
      final minutes = IsoDuration.parseToMinutes(e.duration);
      _duration = TextEditingController(
        text: HumanDuration.formatCompact(minutes),
      );
      _comment = TextEditingController(text: e.comment ?? '');
    } else {
      _duration = TextEditingController(text: '1h');
      _comment = TextEditingController();
    }
  }

  @override
  void dispose() {
    _issue.dispose();
    _duration.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ref.read(appMessengerProvider);
    final settings = ref.read(settingsProvider).asData?.value;
    if (settings == null || !settings.isConfigured) {
      messenger.error('Сначала настройте подключение.');
      return;
    }

    final issueKey = _issue.text.trim().toUpperCase();
    if (issueKey.isEmpty) {
      messenger.error('Укажите задачу (ключ или выбор из списка).');
      return;
    }

    final int minutes;
    try {
      minutes = HumanDuration.parseToMinutes(_duration.text);
    } on FormatException {
      messenger.error(
        'Длительность: число часов (1.5) или с единицами (30m, 1h 30m, 1d).',
      );
      return;
    }

    final duration = IsoDuration.fromMinutes(minutes);
    final start = worklogStartOnDay(
      widget.day,
      existingStart: widget.existing?.start,
    );
    final request = WorklogWriteRequest(
      start: start,
      duration: duration,
      comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
    );

    setState(() => _busy = true);
    try {
      final service = ref.read(worklogServiceProvider);
      final WorklogEntry saved;
      if (_isEdit) {
        saved = await service.update(
          settings,
          widget.existing!.issue.key,
          widget.existing!.id,
          request,
        );
        messenger.success('Запись обновлена');
      } else {
        saved = await service.create(settings, issueKey, request);
        messenger.success('Запись создана');
      }
      notifyWorklogChanged(ref, upsert: saved);
      if (mounted) Navigator.of(context).pop(true);
    } on TrackerApiException catch (e) {
      messenger.fromError(e);
    } catch (e) {
      messenger.fromError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Изменить списание' : 'Новое списание'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_isEdit)
            TextField(
              controller: _issue,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Задача',
                border: OutlineInputBorder(),
              ),
            )
          else
            IssueAutocompleteField(
              controller: _issue,
              enabled: !_busy,
            ),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _duration,
            builder: (context, value, _) {
              final parsed = HumanDuration.tryParseToMinutes(value.text);
              final helper = parsed == null
                  ? HumanDuration.inputExamples
                  : 'Будет списано: ${HumanDuration.formatRu(parsed)}';
              return TextField(
                controller: _duration,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Длительность *',
                  hintText: HumanDuration.inputHint,
                  border: const OutlineInputBorder(),
                  helperText: helper,
                  helperMaxLines: 2,
                  errorText: value.text.trim().isNotEmpty && parsed == null
                      ? 'Не понял формат'
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isEdit ? 'Сохранить' : 'Создать'),
          ),
        ],
      ),
    );
  }
}
