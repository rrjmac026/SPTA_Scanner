import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const SPTAApp());
}

class SPTAApp extends StatelessWidget {
  const SPTAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPTA Payment',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
        scaffoldBackgroundColor: const Color(0xFFF0F4FF),
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Color(0xFF1A3A6B),
            statusBarIconBrightness: Brightness.light,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
