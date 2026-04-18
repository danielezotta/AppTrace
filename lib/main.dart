import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'ui/screens/dashboard_screen.dart';
import 'services/tray_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setMinimumSize(const Size(800, 600));
    await windowManager.setSize(const Size(800, 600));
    await windowManager.setAsFrameless();
    await windowManager.show();
  });
  
  // Initialize tray
  await TrayService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppTrace',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
