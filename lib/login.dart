import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/travel_input_page.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    // 1️⃣ 檢查使用者是否輸入帳號和密碼
    if (_nameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMessageDialog('請輸入帳號和密碼！');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    String? storedName = prefs.getString('name');
    String? storedPassword = prefs.getString('password');

    // 2️⃣ 檢查使用者是否已註冊
    if (storedName == null || storedPassword == null) {
      _showMessageDialog('尚未註冊帳號！請先註冊');
      return;
    }

    // 3️⃣ 檢查使用者名稱是否匹配
    if (_nameController.text != storedName) {
      _showMessageDialog('尚未註冊帳號！請先註冊');
      return;
    }

    // 4️⃣ 檢查密碼是否匹配
    if (_passwordController.text != storedPassword) {
      _showMessageDialog('帳號或密碼錯誤！');
      return;
    }

    // 5️⃣ 帳號密碼正確，轉跳到 TravelInputPage
    if (mounted) { // 確保 Widget 還在
      _showMessageDialog('登入成功！');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TravelInputPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登入')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '使用者名稱'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密碼'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _login, child: const Text('登入')),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterPage()),
                );
              },
              child: const Text('還沒有帳號？註冊'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageDialog(String message) {
    showDialog(
      context: context, // 使用 State 內建的 context
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示', textAlign: TextAlign.center),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // 圓角
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 關閉對話框
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }
}

// 註冊頁面
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _register() async {
    final prefs = await SharedPreferences.getInstance();
    if (_phoneController.text.isNotEmpty &&
        _nameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      await prefs.setString('phone', _phoneController.text);
      await prefs.setString('name', _nameController.text);
      await prefs.setString('password', _passwordController.text);

      if (mounted) {
        _showMessageDialog('註冊成功！請登入');
      }

      // 等待 1 秒後再回到登入頁面，確保提示能顯示
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        _showMessageDialog('請填寫所有欄位');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('註冊')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: '手機號碼'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '使用者名稱'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密碼'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _register, child: const Text('註冊')),
          ],
        ),
      ),
    );
  }

  void _showMessageDialog(String message) {
    showDialog(
      context: context, // 使用 State 內建的 context
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示', textAlign: TextAlign.center),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // 圓角
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 關閉對話框
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }
  
}




