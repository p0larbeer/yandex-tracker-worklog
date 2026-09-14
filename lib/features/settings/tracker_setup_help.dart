import 'dart:convert';

/// Официальные ссылки и тексты справки по подключению к Tracker API.
abstract final class TrackerSetupHelp {
  static const oauthAppsUrl = 'https://oauth.yandex.ru/';
  static const accessDocsUrl =
      'https://yandex.ru/support/tracker/ru/api-ref/access';
  static const orgAdminUrl = 'https://tracker.yandex.ru/admin/orgs';

  static String tokenAuthorizeUrl(String clientId) =>
      'https://oauth.yandex.ru/authorize?response_type=token&client_id=$clientId';

  static const steps = <SetupHelpStep>[
    SetupHelpStep(
      title: 'Создайте OAuth-приложение',
      body:
          'Откройте oauth.yandex.ru → «Создать» → выберите '
          '«Для доступа к API или отладки».',
      url: oauthAppsUrl,
      linkLabel: 'Открыть oauth.yandex.ru',
    ),
    SetupHelpStep(
      title: 'Выдайте права Tracker',
      body:
          'В поле доступа добавьте:\n'
          '• «Запись в трекер» (tracker:write) — нужно для списания времени\n'
          '• или хотя бы «Чтение из трекера» (tracker:read) — только просмотр\n'
          'Для этого приложения рекомендуем tracker:write.',
    ),
    SetupHelpStep(
      title: 'Скопируйте ClientID',
      body:
          'После создания приложения откройте его карточку и скопируйте '
          'значение ClientID.',
      url: oauthAppsUrl,
      linkLabel: 'Мои приложения OAuth',
    ),
    SetupHelpStep(
      title: 'Получите токен',
      body:
          'Вставьте ClientID в поле ниже (или вручную откройте ссылку вида '
          'oauth.yandex.ru/authorize?response_type=token&client_id=…). '
          'Войдите в нужный аккаунт Яндекса — на странице появится токен. '
          'Скопируйте его целиком.',
    ),
    SetupHelpStep(
      title: 'Узнайте ID организации (без прав админа)',
      body:
          'Админка «Организации» обычным сотрудникам недоступна — это нормально.\n\n'
          'В DevTools на tracker.yandex.ru заголовков X-Org-ID / X-Cloud-Org-ID '
          'часто нет: UI ходит через /gateway/…, а не напрямую в API.\n\n'
          'Сделайте так:\n'
          '1. Tracker в браузере → нужная организация.\n'
          '2. F12 → Network → фильтр: Organization или getOrganization.\n'
          '3. Откройте getOrganizationInfo / getOrganizationFront / '
          'listOrganizations → вкладка Response (не Headers).\n'
          '4. Скопируйте JSON целиком (от первой { до последней }) и вставьте '
          'в «Разобрать JSON организации».\n'
          '   Для listOrganizations кандидаты часто: directoryOrganizationId '
          '(Яндекс 360) и id вида bpf… (Cloud).\n\n'
          'Важно: в ответе UI несколько разных id (id, label, trackerId, '
          'orgAliases). Для API нужен тот, который принимает X-Org-ID или '
          'X-Cloud-Org-ID — он может отличаться от полей в ответе. '
          'Перебирайте кандидатов и переключатель Cloud, пока «Проверить '
          'подключение» не станет успешным.\n\n'
          'Если ничего не подходит — спросите у админа значение именно для API.',
      url: 'https://tracker.yandex.ru/',
      linkLabel: 'Открыть Tracker в браузере',
    ),
    SetupHelpStep(
      title: 'Проверьте подключение',
      body:
          'Заполните токен и выбранный ID, нажмите «Проверить и продолжить». '
          'Успех = имя из Tracker (/myself). '
          '401/403/404 — другой кандидат ID или тип заголовка Cloud.',
      url: accessDocsUrl,
      linkLabel: 'Документация доступа к API',
    ),
  ];
}

class SetupHelpStep {
  const SetupHelpStep({
    required this.title,
    required this.body,
    this.url,
    this.linkLabel,
  });

  final String title;
  final String body;
  final String? url;
  final String? linkLabel;
}

/// Кандидат ID организации, извлечённый из JSON UI Tracker.
class OrgIdCandidate {
  const OrgIdCandidate({
    required this.value,
    required this.source,
    required this.preferCloudHeader,
  });

  final String value;
  final String source;
  final bool preferCloudHeader;
}

/// Разбор ответа getOrganizationFront / listOrganizations и т.п.
List<OrgIdCandidate> extractOrgIdCandidates(String rawJson) {
  final seen = <String>{};
  final result = <OrgIdCandidate>[];

  void add(String? value, String source, {required bool cloud}) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return;
    // Не принимать названия организаций как ID
    if (source == 'title' || source == 'name' || source == 'displayName') {
      return;
    }
    final variants = <String>{v};
    if (v.startsWith('org-') && v.length > 4) {
      variants.add(v.substring(4));
    }
    for (final candidate in variants) {
      if (seen.add(candidate)) {
        result.add(
          OrgIdCandidate(
            value: candidate,
            source: source,
            preferCloudHeader: cloud || candidate.startsWith('bpf'),
          ),
        );
      }
    }
  }

  bool looksLikeOrgMap(Map<String, dynamic> map) {
    return map.containsKey('trackerId') ||
        map.containsKey('orgAliases') ||
        map.containsKey('directoryOrganizationId') ||
        map.containsKey('collabOrganizationId') ||
        map.containsKey('trackerEnabled') ||
        (map.containsKey('id') &&
            (map.containsKey('name') || map.containsKey('title'))) ||
        (map.containsKey('id') && map.containsKey('label'));
  }

  final objects = <Map<String, dynamic>>[];
  void collect(dynamic node) {
    if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      if (looksLikeOrgMap(map)) {
        objects.add(map);
      }
      if (map['data'] != null) collect(map['data']);
      for (final key in ['organizations', 'items', 'result']) {
        final list = map[key];
        if (list is List) {
          for (final item in list) {
            collect(item);
          }
        }
      }
    } else if (node is List) {
      for (final item in node) {
        collect(item);
      }
    }
  }

  try {
    collect(jsonDecode(rawJson.trim()));
  } catch (_) {
    // Ниже — regex-fallback по сырому тексту (обрезанный JSON и т.п.)
  }

  for (final obj in objects) {
    add(obj['trackerId']?.toString(), 'trackerId', cloud: true);
    // listOrganizations: cloud id часто в поле id (bpf…)
    final id = obj['id']?.toString();
    add(
      id,
      'id',
      cloud: id != null && id.startsWith('bpf'),
    );
    add(
      obj['directoryOrganizationId']?.toString(),
      'directoryOrganizationId',
      cloud: false,
    );
    add(obj['label']?.toString(), 'label', cloud: false);
    // collab UUID обычно не для Tracker API — низкий приоритет, всё же как кандидат
    add(
      obj['collabOrganizationId']?.toString(),
      'collabOrganizationId',
      cloud: false,
    );
    final aliases = obj['orgAliases'];
    if (aliases is List) {
      for (final alias in aliases) {
        if (alias is Map) {
          add(alias['id']?.toString(), 'orgAliases.id', cloud: false);
        }
      }
    }
  }

  // Fallback: вытащить типичные id из текста, если JSON обрезан или неизвестный формат
  if (result.isEmpty) {
    final text = rawJson;
    for (final m in RegExp(r'"trackerId"\s*:\s*"([^"]+)"').allMatches(text)) {
      add(m.group(1), 'trackerId', cloud: true);
    }
    for (final m in RegExp(
      r'"directoryOrganizationId"\s*:\s*"([^"]+)"',
    ).allMatches(text)) {
      add(m.group(1), 'directoryOrganizationId', cloud: false);
    }
    for (final m in RegExp(r'"id"\s*:\s*"(bpf[^"]+)"').allMatches(text)) {
      add(m.group(1), 'id', cloud: true);
    }
    for (final m in RegExp(r'"id"\s*:\s*(\d+)').allMatches(text)) {
      add(m.group(1), 'id', cloud: false);
    }
    for (final m in RegExp(r'\b(bpf[a-z0-9]+)\b').allMatches(text)) {
      add(m.group(1), 'text:bpf', cloud: true);
    }
  }

  int rank(OrgIdCandidate c) {
    if (c.source == 'trackerId') return 0;
    if (c.source == 'id' && c.preferCloudHeader) return 1;
    if (c.source == 'directoryOrganizationId') return 2;
    if (c.source == 'orgAliases.id') return 3;
    if (c.source == 'label') return 4;
    if (c.source == 'id') return 5;
    return 6;
  }

  result.sort((a, b) => rank(a).compareTo(rank(b)));
  return result;
}
