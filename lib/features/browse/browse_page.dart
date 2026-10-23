import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/my_issues_panel.dart';
import 'widgets/other_worklog_panel.dart';

/// Раздел «Обзор»: мои задачи + worklog по пользователю (RO).
class BrowsePage extends ConsumerWidget {
  const BrowsePage({super.key});

  static const String routeName = '/browse';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Обзор'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Мои задачи'),
              Tab(text: 'По пользователю'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MyIssuesPanel(),
            OtherWorklogPanel(),
          ],
        ),
      ),
    );
  }
}
