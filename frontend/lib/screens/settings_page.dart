import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/preference_controller.dart';
import '../models/user_preference.dart';
import '../widgets/app_page_container.dart';
import '../widgets/section_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const List<String> configurableTabs = ['calendar', 'todo', 'note'];

  late List<String> _enabledTabs;
  late List<String> _tabOrder;
  late String _initialTab;
  late String _themeMode;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;

    final pref = context.read<PreferenceController>().preference;
    final safePref = pref ??
        UserPreference(
          enabledTabs: configurableTabs,
          tabOrder: configurableTabs,
          initialTab: 'calendar',
          themeMode: 'system',
        );

    _enabledTabs = List<String>.from(
      safePref.enabledTabs.where(configurableTabs.contains),
    );

    _tabOrder = List<String>.from(
      safePref.tabOrder.where(configurableTabs.contains),
    );

    if (_tabOrder.isEmpty) {
      _tabOrder = List<String>.from(configurableTabs);
    }

    _initialTab = configurableTabs.contains(safePref.initialTab)
        ? safePref.initialTab
        : _enabledTabs.isNotEmpty
            ? _enabledTabs.first
            : configurableTabs.first;

    _themeMode = safePref.themeMode;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final availableInitialTabs =
        _tabOrder.where((tab) => _enabledTabs.contains(tab)).toList();

    if (availableInitialTabs.isNotEmpty &&
        !availableInitialTabs.contains(_initialTab)) {
      _initialTab = availableInitialTabs.first;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: AppPageContainer(
        child: ListView(
          children: [
            SectionCard(
              title: '表示する機能',
              description: 'ホーム画面の下部タブに表示する機能を選びます。',
              child: Column(
                children: configurableTabs.map((tab) {
                  final isEnabled = _enabledTabs.contains(tab);

                  return SwitchListTile(
                    secondary: Icon(_iconForTab(tab)),
                    title: Text(_labelForTab(tab)),
                    value: isEnabled,
                    onChanged: (value) {
                      setState(() {
                        if (value) {
                          if (!_enabledTabs.contains(tab)) {
                            _enabledTabs.add(tab);
                          }
                          if (!_tabOrder.contains(tab)) {
                            _tabOrder.add(tab);
                          }
                          if (_enabledTabs.length == 1) {
                            _initialTab = tab;
                          }
                        } else {
                          if (_enabledTabs.length == 1 &&
                              _enabledTabs.contains(tab)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('少なくとも1つのタブは表示してください'),
                              ),
                            );
                            return;
                          }
                          _enabledTabs.remove(tab);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'タブの並び順',
              description: 'ドラッグして表示順を変更できます。',
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tabOrder.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _tabOrder.removeAt(oldIndex);
                    _tabOrder.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final tab = _tabOrder[index];
                  final isEnabled = _enabledTabs.contains(tab);

                  return ListTile(
                    key: ValueKey(tab),
                    leading: Icon(
                      _iconForTab(tab),
                      color: isEnabled
                          ? null
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(_labelForTab(tab)),
                    subtitle: Text(isEnabled ? '表示中' : '非表示'),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: '起動時に開くタブ',
              description: 'ログイン後に最初に表示する画面を選びます。',
              child: DropdownButtonFormField<String>(
                value: availableInitialTabs.isNotEmpty ? _initialTab : null,
                items: availableInitialTabs
                    .map(
                      (tab) => DropdownMenuItem(
                        value: tab,
                        child: Text(_labelForTab(tab)),
                      ),
                    )
                    .toList(),
                onChanged: availableInitialTabs.isEmpty
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _initialTab = value;
                          });
                        }
                      },
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'テーマ',
              description: 'アプリ全体の見た目を変更します。',
              child: DropdownButtonFormField<String>(
                value: _themeMode,
                items: const [
                  DropdownMenuItem(value: 'system', child: Text('システム設定')),
                  DropdownMenuItem(value: 'light', child: Text('ライト')),
                  DropdownMenuItem(value: 'dark', child: Text('ダーク')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _themeMode = value;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('設定を保存'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('ログアウト'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForTab(String tab) {
    switch (tab) {
      case 'calendar':
        return Icons.calendar_month;
      case 'todo':
        return Icons.check_box;
      case 'note':
        return Icons.note;
      default:
        return Icons.help_outline;
    }
  }

  String _labelForTab(String tab) {
    switch (tab) {
      case 'calendar':
        return 'カレンダー';
      case 'todo':
        return 'タスク';
      case 'note':
        return 'ノート';
      default:
        return tab;
    }
  }

  Future<void> _save() async {
    if (_enabledTabs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('少なくとも1つのタブを表示してください')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final sortedEnabledTabs =
          _tabOrder.where((tab) => _enabledTabs.contains(tab)).toList();

      final updated = UserPreference(
        enabledTabs: sortedEnabledTabs,
        tabOrder: List<String>.from(_tabOrder),
        initialTab: _initialTab,
        themeMode: _themeMode,
      );

      await context.read<PreferenceController>().updatePreferences(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('ログアウトしますか？'),
          content: const Text('現在のアカウントからログアウトします。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ログアウト'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    if (!mounted) return;

    final preferenceController = context.read<PreferenceController>();
    final authController = context.read<AuthController>();

    preferenceController.clear();
    await authController.logout();

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}