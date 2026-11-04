import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/admin_service.dart';
import 'theme/admin_colors.dart';
import 'screens/admin_main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.web,
    );
  } catch (e) {
    debugPrint('Firebase init web fallback: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AdminService(),
      child: const WhyIBuyAdminApp(),
    ),
  );
}

class WhyIBuyAdminApp extends StatelessWidget {
  const WhyIBuyAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminService>();

    return MaterialApp(
      title: 'Why I Buy - Quản Trị Hệ Thống (Flutter Web)',
      debugShowCheckedModeBanner: false,
      themeMode: admin.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(
          primary: AdminColors.primary,
          surface: Color(0xFFFFFFFF),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020617),
        colorScheme: const ColorScheme.dark(
          primary: AdminColors.primary,
          surface: Color(0xFF0F172A),
        ),
      ),
      home: const AdminMainLayout(),
    );
  }
}
