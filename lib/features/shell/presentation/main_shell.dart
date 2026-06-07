import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../actions/presentation/actions_page.dart';
import '../../calendar/presentation/calendar_page.dart';
import '../../home/presentation/home_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../settings/presentation/settings_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onOpenTab: _selectTab),
      const CalendarPage(),
      const ActionsPage(),
      const ReportsPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.today),
            selectedIcon: Icon(AppIcons.todaySelected),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.calendar),
            selectedIcon: Icon(AppIcons.calendarSelected),
            label: '日历',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.rehab),
            selectedIcon: Icon(AppIcons.rehabSelected),
            label: '康复',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.reports),
            selectedIcon: Icon(AppIcons.reportsSelected),
            label: '报告',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.settings),
            selectedIcon: Icon(AppIcons.settingsSelected),
            label: '设置',
          ),
        ],
      ),
    );
  }

  void _selectTab(int value) {
    setState(() => _index = value);
  }
}
