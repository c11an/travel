import 'package:flutter/material.dart';
import 'my_journal_tab.dart';
import 'community_tab.dart';

class JournalPage extends StatelessWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('日誌'),
          bottom: const TabBar(
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
