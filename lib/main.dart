import 'package:flutter/material.dart';
import 'router.dart'; // Import the router
import 'auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await authProvider.checkLoginStatus(); // Cek status login sebelum app mulai
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use MaterialApp.router to integrate GoRouter.
    return MaterialApp.router(
      routerConfig: router, // Pass the router configuration
      title: 'Stats App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}
