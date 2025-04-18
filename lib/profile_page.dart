import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('個人頁面')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 頭像與姓名
            Row(
              children: [
                const CircleAvatar(radius: 30, child: Icon(Icons.person, size: 30)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('使用者名稱', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('帳號資訊'),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 功能列
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFeatureButton(Icons.upload_file, '上傳行程'),
                _buildFeatureButton(Icons.favorite, '我的收藏'),
                _buildFeatureButton(Icons.settings, '設定'),
              ],
            ),

            const SizedBox(height: 30),
            const Divider(),

            // 喜好標籤
            Row(
              children: const [
                Icon(Icons.star, color: Colors.orange),
                SizedBox(width: 8),
                Text('喜好類型：自然 / 美食'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureButton(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.blueAccent),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
