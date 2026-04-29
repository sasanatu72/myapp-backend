import 'package:flutter/material.dart';

import '../screens/settings_page.dart';

class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '設定',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SettingsPage(),
          ),
        );
      },
    );
  }
}
