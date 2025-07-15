import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:project_va1/pages/login_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MRT Pink Line',
      theme: ThemeData(primarySwatch: Colors.deepPurple, fontFamily: 'Sarabun'),
      home: const LoginPage(),
    );
  }
}
