// 新增檔案：event_detail_page.dart
import 'package:flutter/material.dart';

class EventDetailPage extends StatelessWidget {
  final Map<String, String> event;

  const EventDetailPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('活動詳情')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event['title'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("📅 活動時間：${event['date']}"),
            const SizedBox(height: 10),
            Text("📍 活動地點：${event['location']}"),
            const SizedBox(height: 20),
            const Text("這裡可以補上更多詳情說明，例如活動內容簡介、主辦單位、票價等等。"),
          ],
        ),
      ),
    );
  }
}
