import 'package:flutter/material.dart';
import 'my_journal_tab.dart';

// ===== 奶茶文青風色票（全站統一） =====
const kBgCream     = Color(0xFFFAF3E0); // 背景：淡奶茶米色
const kCardBase    = Color(0xFFEAD7B7); // 卡片底：奶茶棕
const kPressedTint = Color(0xFFD6C2A1); // 按下/hover
const kTextDark    = Color(0xFF4E342E); // 文字：深棕
const kAccent      = Color(0xFFB48A60); // 拿鐵咖啡主色

class JournalPage extends StatelessWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgCream,
      appBar: AppBar(
        backgroundColor: kBgCream,
        elevation: 0,
        centerTitle: true, // ✅ 標題置中
        title: const Text(
          '我的行程',
          style: TextStyle(
            color: kTextDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: kTextDark),
      ),
      body: const MyJournalTab(), // ✅ 直接顯示「我的行程」分頁
    );
  }
}
