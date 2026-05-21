import 'package:flutter/material.dart';
import 'package:my_app/features/hermes/screens/sessions_screen.dart';
import 'package:my_app/features/hermes/screens/skills_screen.dart';
import 'package:my_app/features/hermes/screens/models_screen.dart';
import 'package:my_app/features/hermes/screens/cron_screen.dart';

class HermesApp extends StatelessWidget {
  const HermesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HermesHomePage(),
    );
  }
}

class HermesHomePage extends StatefulWidget {
  const HermesHomePage({super.key});

  @override
  State<HermesHomePage> createState() => _HermesHomePageState();
}

class _HermesHomePageState extends State<HermesHomePage> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    SessionsScreen(),
    SkillsScreen(),
    ModelsScreen(),
    CronScreen(),
  ];

  static const _destinations = [
    (icon: Icons.chat, label: '会话'),
    (icon: Icons.auto_awesome, label: '技能'),
    (icon: Icons.model_training, label: '模型'),
    (icon: Icons.schedule, label: '定时'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: _destinations
                .map((d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      label: Text(d.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}
