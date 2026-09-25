import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const ClashManagerApp());
}

class ClashManagerApp extends StatelessWidget {
  const ClashManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clash 路由器管理',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
