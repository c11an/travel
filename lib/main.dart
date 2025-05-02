import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/directions_api_test.dart';
import 'package:travel/home.dart';
import 'package:travel/login.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light; // 預設是亮色模式

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
        prefs.setBool('isDarkMode', true);
      } else {
        _themeMode = ThemeMode.light;
        prefs.setBool('isDarkMode', false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '旅遊應用',
      themeMode: _themeMode, // ⭐️ 這裡支援切換
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light, // ⭐️ 這行一定要加！
          ),
          useMaterial3: true,
        ),
        
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark, // ⭐️ 這行一定要加！
          ),
          useMaterial3: true,
        ),

      home: const HomePage(), // 預設從登入頁進入
    );
  }
}