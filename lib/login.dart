// 完整 Flutter 登入與註冊頁面，已連接 Django 後端 API，新增姓、名、email
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/home.dart';
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  //以下連接後端程式碼的位置
  Future<void> _login() async {
    if (_nameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMessageDialog('請輸入帳號和密碼！');
      return;
    }

    final response = await http.post(
      Uri.parse('https://aafc-114-36-223-135.ngrok-free.app/api/auth/login/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": _nameController.text,
        "password": _passwordController.text,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final accessToken = data['access'];
      final refreshToken = data['refresh'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', accessToken);
      await prefs.setString('refreshToken', refreshToken);
      await prefs.setString('username', _nameController.text);

      await http.post(
        Uri.parse(
          'https://aafc-114-36-223-135.ngrok-free.app/api/auth/record-login/',
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": _nameController.text}),
      );

      _showMessageDialog('登入成功！\n使用者：${_nameController.text}');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      _showMessageDialog('登入失敗，請確認帳密');
    }
  }

  //以上連接後端程式碼的位置
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登入'),
        backgroundColor: const Color.fromARGB(255, 178, 144, 121),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '使用者名稱',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '密碼',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 239, 231, 218),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                '登入',
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 178, 144, 121),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  child: const Text(
                    '還沒有帳號？註冊',
                    style: TextStyle(
                      color: Color.fromARGB(255, 54, 105, 163),
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                TextButton(
                  onPressed: () {
                    _showMessageDialog('請聯繫客服處理密碼重設');
                  },
                  child: const Text(
                    '忘記密碼？',
                    style: TextStyle(
                      color: Color.fromARGB(255, 54, 105, 163),
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示', textAlign: TextAlign.center),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }
}

// 🔻 RegisterPage 已新增：姓、名、email 欄位，並一併傳給後端
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedBirthday;
  String? _selectedPreference;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _register() async {
    String phone = _phoneController.text;
    String name = _nameController.text;
    String password = _passwordController.text;
    String email = _emailController.text;
    String firstName = _firstNameController.text;
    String lastName = _lastNameController.text;

    if (phone.isEmpty ||
        name.isEmpty ||
        password.isEmpty ||
        email.isEmpty ||
        firstName.isEmpty ||
        lastName.isEmpty ||
        _selectedGender == null ||
        _selectedBirthday == null ||
        _selectedPreference == null) {
      _showMessageDialog('請填寫所有欄位');
      return;
    }

    if (!RegExp(r"^09\d{8}").hasMatch(phone)) {
      _showMessageDialog('手機號碼輸入錯誤');
      return;
    }

    final response = await http.post(
      Uri.parse(
        'https://aafc-114-36-223-135.ngrok-free.app/api/auth/register/',
      ),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": name,
        "password": password,
        "phone": phone,
        "gender": _selectedGender,
        "birthday": _selectedBirthday!.toIso8601String(),
        "preference": _selectedPreference,
        "email": email,
        "first_name": firstName,
        "last_name": lastName,
      }),
    );

    if (response.statusCode == 201) {
      _showMessageDialog('註冊成功！請登入');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pushAndRemoveUntil(
           context,
           MaterialPageRoute(builder: (context) => const HomePage()),
           (route) => false, // ⭐️清空之前所有頁面
         );
      }
    } else {
      try {
        final decodedBody = utf8.decode(response.bodyBytes); // 防止亂碼
        final res = jsonDecode(decodedBody);
        _showMessageDialog("註冊失敗：${res['error'] ?? decodedBody}");
      } catch (e) {
        _showMessageDialog("註冊失敗（格式解析錯誤）：${response.body}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const deepBrown = Color.fromARGB(255, 101, 67, 33);

    return Scaffold(
      appBar: AppBar(title: const Text('註冊')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: '姓',
                  labelStyle: TextStyle(color: deepBrown),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 239, 231, 218),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: '名',
                  labelStyle: TextStyle(color: deepBrown),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 239, 231, 218),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: '電子郵件',
                  labelStyle: TextStyle(color: deepBrown),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 239, 231, 218),
                ),
              ),
              const SizedBox(height: 20),
              // 原本註冊欄位們繼續...
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: '手機號碼',
                  labelStyle: TextStyle(color: deepBrown),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 239, 231, 218),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '使用者名稱',
                  labelStyle: TextStyle(color: deepBrown),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 239, 231, 218),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '密碼',
                  labelStyle: TextStyle(color: deepBrown),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 239, 231, 218),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                hint: const Text('選擇性別', style: TextStyle(color: deepBrown)),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedGender = newValue;
                  });
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color.fromARGB(255, 239, 231, 218),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items:
                    ['男', '女', '不透漏'].map<DropdownMenuItem<String>>((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(color: deepBrown),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _birthdayController,
                decoration: InputDecoration(
                  labelText: '生日',
                  labelStyle: TextStyle(color: deepBrown),
                  hintText: '選擇生日',
                  hintStyle: TextStyle(color: deepBrown),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 239, 231, 218),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context),
                  ),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedPreference,
                hint: const Text('選擇旅遊偏好', style: TextStyle(color: deepBrown)),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPreference = newValue;
                  });
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color.fromARGB(255, 239, 231, 218),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items:
                    ['海灘', '山脈', '城市', '歷史遺跡'].map<DropdownMenuItem<String>>((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(color: deepBrown),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 239, 231, 218),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '註冊',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color.fromARGB(255, 178, 144, 121),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示', textAlign: TextAlign.center),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }
}