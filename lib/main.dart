import 'package:ai_pdf_viewer/config/theme_data_customized.dart';
import 'package:ai_pdf_viewer/services/env_handler.dart';
import 'package:ai_pdf_viewer/view/home.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EnvHandler.loadEnv();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeDataCustomized.getTheme(),
      home: const Home(),
    );
  }
}
