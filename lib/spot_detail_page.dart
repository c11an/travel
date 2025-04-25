// lib/spot_detail_page.dart
import 'package:flutter/material.dart';

class SpotDetailPage extends StatelessWidget {
  final Map<String, dynamic> spot;

  const SpotDetailPage({super.key, required this.spot});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(spot['name'] ?? '景點詳情')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (spot['imageUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  spot['imageUrl'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              spot['name'] ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('地點：${spot['location'] ?? '未知'}'),
            const SizedBox(height: 8),
            Text('類型：${spot['type'] ?? '無分類'}'),
            const SizedBox(height: 8),
            Text('簡介：${spot['description'] ?? '暫無說明'}'),
          ],
        ),
      ),
    );
  }
}
