import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/travel_day_page.dart'; // ⭐記得import

class AIRecommendResultPage extends StatefulWidget {
  final String? city;
  final double? budget;
  final String? transport;
  final List<String>? types;
  final List<Map<String, String>> spots;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? gptRecommendation;
  final List<Map<String, String>> allSpots; // 🔧 新增


  const AIRecommendResultPage({
    super.key,
    this.city,
    this.budget,
    this.transport,
    this.types,
    required this.spots,
    required this.allSpots, // ✅ 接收 allSpots
    this.startDate,
    this.endDate,
    this.gptRecommendation,
  });

  @override
  State<AIRecommendResultPage> createState() => _AIRecommendResultPageState();
}

class _AIRecommendResultPageState extends State<AIRecommendResultPage> {
  List<Map<String, dynamic>> recommendedSpots = [];
  final Set<String> favoriteSpots = {}; // ✅收藏列表

  @override
  void initState() {
    super.initState();
    _loadRecommendedSpots();
  }

  void _loadRecommendedSpots() {
    setState(() {
      recommendedSpots = widget.spots.map((spot) {
        return {
          'name': spot['Name'] ?? '',
          'type': spot['Category'] ?? '',
          'location': spot['Region'] ?? '',
          'imageUrl': spot['Picture1'] ?? '',
          'rating': 4.5,
          'description': spot['Description'] ?? '沒有描述',
        };
      }).toList();
    });
  }

  void _convertGptToTravelPage() {
    final gptText = widget.gptRecommendation ?? '';

    if (widget.startDate == null || widget.endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 未設定旅遊日期，無法建立日行程')),
      );
      return;
    }

    if (gptText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ GPT 回傳內容為空')),
      );
      return;
    }

    // 🔍 Step 1: 解析 GPT 行程
    final Map<int, List<String>> dayMap = {};
    final lines = gptText.split('\n');
    int currentDay = -1;

    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('Day')) {
        final match = RegExp(r'\d+').firstMatch(line);
        if (match != null) {
          currentDay = int.parse(match.group(0)!) - 1;
          dayMap[currentDay] = [];
        }
      } else if (line.contains('：') && currentDay >= 0) {
        final content = line.split('：')[1];
        final names = content
            .split(RegExp(r'[、,，。]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        dayMap[currentDay]?.addAll(names);
      }
    }

    print('🔎 Day Map keys: ${dayMap.keys}');

    // 🔧 根據旅遊實際天數限制列表長度
    final maxDayIndex = dayMap.keys.isEmpty ? 0 : dayMap.keys.reduce((a, b) => a > b ? a : b);
    final tripDays = max(widget.endDate!.difference(widget.startDate!).inDays + 1, maxDayIndex + 1);
    List<List<Map<String, String>>> matchedSpots = List.generate(tripDays, (_) => []);
    for (final entry in dayMap.entries) {
      final int dayIndex = entry.key;

      if (dayIndex >= matchedSpots.length) continue; // ✅ 避免超出天數索引

      final List<String> gptNames = entry.value;
      for (final gptName in gptNames) {
        Map<String, String>? bestSpot;

        for (final spot in widget.allSpots) {
          final spotName = spot['Name'] ?? '';
          if (spotName.contains(gptName) || gptName.contains(spotName)) {
            bestSpot = spot;
            break;
          }
        }

        if (bestSpot != null) {
          matchedSpots[dayIndex].add(bestSpot);
        }
      }
    }

    print('🧠 GPT Recommendation:\n$gptText');
    print('🗺️ 景點資料數量：${widget.spots.length}');
    for (int day = 0; day < matchedSpots.length; day++) {
      final spots = matchedSpots[day];
      print('Day ${day + 1}: ${spots.map((s) => s['Name']).join(", ")}');
    }

    final totalMatched = matchedSpots.fold<int>(0, (sum, list) => sum + list.length);
    if (totalMatched == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 找不到任何對應景點，頁面仍將開啟')),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelDayPage(
          tripName: 'GPT推薦行程',
          startDate: widget.startDate ?? DateTime.now(),
          endDate: widget.endDate ?? DateTime.now().add(Duration(days: matchedSpots.length - 1)),
          budget: widget.budget?.toInt() ?? 0,
          transport: widget.transport ?? '不限',
          initialSpots: matchedSpots,
          readOnly: false,
        ),
      ),
    ).then((result) async {
      if (result != null && result is Map<String, dynamic>) {
        final prefs = await SharedPreferences.getInstance();
        final tripList = prefs.getStringList('trip_list') ?? [];
        tripList.add(jsonEncode(result));
        await prefs.setStringList('trip_list', tripList);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ GPT 行程已儲存至行程規劃')),
        );
      }
    });
  }



  // ✅ 模糊比對相似度：Jaccard-like 比對
  double _stringSimilarity(String a, String b) {
    final s1 = a.toLowerCase();
    final s2 = b.toLowerCase();
    int matches = 0;

    for (int i = 0; i < s1.length; i++) {
      if (s2.contains(s1[i])) {
        matches++;
      }
    }

    return matches / s2.length;
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI推薦結果'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 推薦條件簡述
            Text('出發地：${widget.city ?? "未指定"}'),
            if (widget.startDate != null && widget.endDate != null)
              Text(
                '旅遊時間：${DateFormat('yyyy/MM/dd').format(widget.startDate!)} ~ ${DateFormat('yyyy/MM/dd').format(widget.endDate!)}',
              )
            else
              const Text('旅遊時間：未指定'),
            Text('預算：${widget.budget?.round() ?? 0} 元'),
            //Text('交通方式：${widget.transport ?? "不限"}'),
            Text('旅遊類型：${widget.types?.join(', ') ?? "不限"}'),
            const SizedBox(height: 16),

            // 🔮 GPT 推薦行程
            if ((widget.gptRecommendation ?? '').trim().isNotEmpty) ...[
              Text(
                '🔮 GPT 推薦行程',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _parseGptRecommendation(widget.gptRecommendation!),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _convertGptToTravelPage,
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('查看AI推薦行程'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新推薦'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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



  List<Widget> _parseGptRecommendation(String text) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('Day')) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(
          Text(
            line,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        );
      } else if (line.contains('：')) {
        final parts = line.split('：');
        if (parts.length > 1) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join('：').trim(); // 防止有多個「：」

          widgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$key：",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(value)),
                ],
              ),
            ),
          );
        } else {
          // 若不是 key：value 格式，直接當成一般段落顯示
          widgets.add(Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(line),
          ));
        }

      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: Text(line),
        ));
      }
    }

    return widgets;
  }

}
