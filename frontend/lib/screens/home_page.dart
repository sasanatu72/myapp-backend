import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/preference_controller.dart';
import '../models/user_preference.dart';
import 'calendar_page.dart';
import 'note_page.dart';
import 'todo_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const List<String> _supportedTabs = [
    'calendar',
    'todo',
    'note',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final controller = context.read<PreferenceController>();
      await controller.loadPreferences();

      final pref = controller.preference;
      if (pref == null) return;

      final tabs = _resolvedTabs(pref);
      final initialIndex = tabs.indexOf(pref.initialTab);

      if (mounted) {
        setState(() {
          _selectedIndex = initialIndex >= 0 ? initialIndex : 0;
        });
      }
    });
  }

  List<String> _resolvedTabs(UserPreference? pref) {
    if (pref == null) return _supportedTabs;

    final enabledTabs = pref.enabledTabs.where(_supportedTabs.contains).toSet();

    if (enabledTabs.isEmpty) {
      return _supportedTabs;
    }

    final orderedTabs = pref.tabOrder
        .where((tab) => _supportedTabs.contains(tab) && enabledTabs.contains(tab))
        .toList();

    for (final tab in _supportedTabs) {
      if (enabledTabs.contains(tab) && !orderedTabs.contains(tab)) {
        orderedTabs.add(tab);
      }
    }

    return orderedTabs.isEmpty ? _supportedTabs : orderedTabs;
  }

  Widget _buildPage(String tabKey) {
    switch (tabKey) {
      case 'calendar':
        return const CalendarPage();
      case 'todo':
        return const TodoPage();
      case 'note':
        return const NotePage();
      default:
        return const CalendarPage();
    }
  }

  NavigationDestination _buildDestination(String tabKey) {
    switch (tabKey) {
      case 'calendar':
        return const NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'カレンダー',
        );
      case 'todo':
        return const NavigationDestination(
          icon: Icon(Icons.check_box_outlined),
          selectedIcon: Icon(Icons.check_box),
          label: 'タスク',
        );
      case 'note':
        return const NavigationDestination(
          icon: Icon(Icons.note_outlined),
          selectedIcon: Icon(Icons.note),
          label: 'ノート',
        );
      default:
        return const NavigationDestination(
          icon: Icon(Icons.help_outline),
          label: '不明',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferenceController = context.watch<PreferenceController>();

    if (preferenceController.isLoading && preferenceController.preference == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = _resolvedTabs(preferenceController.preference);
    final currentIndex = _selectedIndex >= tabs.length ? 0 : _selectedIndex;

    return Scaffold(
      body: _buildPage(tabs[currentIndex]),
      bottomNavigationBar: tabs.length >= 2
          ? NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: tabs.map(_buildDestination).toList(),
            )
          : null,
    );
  }
}
