import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:travel/login.dart'; // 回到登入用
import 'package:travel/main.dart'; // 切換深色模式用

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _isDarkMode = false;
  String _appVersion = 'v1.0.0'; // 預設版本號

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _loadAppVersion();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${info.version}';
    });
  }

  Future<void> _toggleThemeMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = value;
    });
    prefs.setBool('isDarkMode', _isDarkMode);
    MyApp.of(context)?.toggleTheme(); // 呼叫 main.dart 的 toggleTheme
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // 清除登入資訊

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _showChangePasswordDialog() {
    String newPassword = '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('修改密碼'),
        content: TextField(
          obscureText: true,
          decoration: const InputDecoration(hintText: '輸入新密碼'),
          onChanged: (value) {
            newPassword = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (newPassword.isNotEmpty) {
                // 這裡可以呼叫後端API來修改密碼
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ 密碼修改成功（模擬）')),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('確定修改'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定中心')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('修改密碼'),
            onTap: _showChangePasswordDialog,
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('登出', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('確認登出'),
                  content: const Text('確定要登出嗎？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('確定'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();

                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginPage(),
                      settings: const RouteSettings(arguments: 'logged_out'),
                    ),
                    (route) => false,
                  );
                }
              }
            },
          ),


          SwitchListTile(
            secondary: const Icon(Icons.brightness_6),
            title: const Text('切換深色模式'),
            value: _isDarkMode,
            onChanged: _toggleThemeMode,
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('APP版本'),
            subtitle: Text(_appVersion),
          ),
        ],
      ),
    );
  }
}
