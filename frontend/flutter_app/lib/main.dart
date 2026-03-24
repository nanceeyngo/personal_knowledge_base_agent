import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'screens/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Make status bar transparent so our dark theme shows through
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    // ProviderScope is required at the root for Riverpod
    const ProviderScope(
      child: RagApp(),
    ),
  );
}

class RagApp extends StatelessWidget {
  const RagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Knowledge Base AI Chatbot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}