import 'package:flutter/material.dart';
import 'my_journal_tab.dart';
import 'community_tab.dart';

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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kBgCream,
        appBar: AppBar(
          backgroundColor: kBgCream,
          elevation: 0,
          title: const Text(
            '日誌',
            style: TextStyle(
              color: kTextDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: kTextDark),
          bottom: const TabBar(
            indicatorColor: kAccent,
            labelColor: kTextDark,
            unselectedLabelColor: kTextDark,
            tabs: [
              Tab(text: '我的行程'),
              Tab(text: '社群'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MyJournalTab(),   // 👈 拆出去的分頁
            CommunityTab(),   // 👈 拆出去的分頁
          ],
        ),
      ),
    );
  }
}
