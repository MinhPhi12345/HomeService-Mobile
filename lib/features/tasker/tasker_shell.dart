import 'package:flutter/material.dart';

import '../../widgets/app_nav.dart';
import '../common/account_page.dart';
import '../common/notifications_page.dart';
import 'jobs_page.dart';
import 'tasker_home_page.dart';

/// Khung chính của Tasker: Nhận việc · Lịch làm · Thông báo · Tài khoản.
class TaskerShell extends StatefulWidget {
  const TaskerShell({super.key});

  @override
  State<TaskerShell> createState() => _TaskerShellState();
}

class _TaskerShellState extends State<TaskerShell> {
  final _homeKey = GlobalKey<TaskerHomePageState>();
  final _jobsKey = GlobalKey<JobsPageState>();

  @override
  Widget build(BuildContext context) {
    return AppNavShell(
      items: const [
        NavItem(
          icon: Icons.work_outline_rounded,
          selectedIcon: Icons.work_rounded,
          label: 'Nhận việc',
        ),
        NavItem(
          icon: Icons.event_note_outlined,
          selectedIcon: Icons.event_note_rounded,
          label: 'Lịch làm',
        ),
        NavItem(
          icon: Icons.notifications_none_rounded,
          selectedIcon: Icons.notifications_rounded,
          label: 'Thông báo',
          showsUnread: true,
        ),
        NavItem(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: 'Tài khoản',
        ),
      ],
      onTabChanged: (index) {
        if (index == 0) _homeKey.currentState?.reload();
        if (index == 1) _jobsKey.currentState?.reload();
      },
      pageBuilder: (context, index, shell) => switch (index) {
        0 => TaskerHomePage(key: _homeKey, onOpenJobs: () => shell.goTo(1)),
        1 => JobsPage(key: _jobsKey),
        2 => NotificationsPage(onUnreadChanged: shell.setUnread),
        _ => const AccountPage(),
      },
    );
  }
}
