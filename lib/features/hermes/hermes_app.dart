import 'package:flutter/material.dart';
import 'package:my_app/features/hermes/screens/sessions_screen.dart';
import 'package:my_app/features/hermes/screens/chat_screen.dart';

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
      home: const SessionsScreen(),
      routes: {
        '/sessions': (context) => const SessionsScreen(),
        '/chat': (context) => const ChatScreen(sessionId: ''),
      },
    );
  }
}
