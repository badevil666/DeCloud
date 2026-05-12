import 'package:flutter/material.dart';
import 'screens/mainNavigation.dart';
import 'core/auth_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthNotifier().init();
  runApp(const DecloudApp());
}

class DecloudApp extends StatelessWidget {
  const DecloudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Decloud',
      theme: ThemeData(fontFamily: 'SF Pro Display'), // Optional: Add your font
      home: MainNavigation(),
    );
  }
}
