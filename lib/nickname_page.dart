import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/home.dart';
import 'package:uuid/uuid.dart';

class NicknamePage extends StatefulWidget {
  const NicknamePage({super.key});

  @override
  State<NicknamePage> createState() => _NicknamePageState();
}

class _NicknamePageState extends State<NicknamePage> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _saveNickname() async {
    final prefs = await SharedPreferences.getInstance();
    final nickname = _controller.text.trim();
    final uuid = const Uuid().v4();

    if (nickname.isEmpty) return;

    await prefs.setString('nickname', nickname);
    await prefs.setString('uuid', uuid);

    // 導向首頁
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("歡迎使用旅人 App！\n請輸入你的旅人暱稱：", textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "例如：旅人小明"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _saveNickname, child: const Text("開始使用"))
          ],
        ),
      ),
    );
  }
}
