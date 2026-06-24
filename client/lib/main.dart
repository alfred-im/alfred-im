import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/alfred_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlfredApp());
}

class AlfredApp extends StatelessWidget {
  const AlfredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alfred',
      debugShowCheckedModeBanner: false,
      theme: AlfredTheme.light,
      home: const HomeScreen(),
    );
  }
}
