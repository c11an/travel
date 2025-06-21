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
  final String? mood;
  final String? need;

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
    this.mood,
    this.need,
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
    print('🧠 mood: ${widget.mood}, 🎯 need: ${widget.need}');
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

  void _convertGptToTravelPage() async {
  try {
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

    // 🧠 解析 GPT 內容
    final Map<int, List<String>> dayMap = {};
    final lines = gptText.split('\n');
    int currentDay = -1;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('Day')) {
        final match = RegExp(r'Day\s*(\d+)').firstMatch(line);
        if (match != null) {
          currentDay = int.parse(match.group(1)!) - 1;
          dayMap[currentDay] = [];
        }
      } else if (line.contains('：') && currentDay >= 0) {
        final parts = line.split('：');
        if (parts.length > 1) {
          final content = parts.sublist(1).join('：').trim();
          final names = content
              .split(RegExp(r'[、,，。]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          dayMap[currentDay]?.addAll(names);
        }
      }
    }

    print('🔎 Day Map keys: ${dayMap.keys}');

    if (dayMap.isEmpty) {
      throw Exception('GPT 行程內容無法解析成天數結構');
    }

    // 📅 計算行程天數
    final maxDayIndex = dayMap.keys.reduce(max);
    final tripDays = max(widget.endDate!.difference(widget.startDate!).inDays + 1, maxDayIndex + 1);
    final matchedSpots = List.generate(tripDays, (_) => <Map<String, String>>[]);

    // 📍 景點比對
    for (final entry in dayMap.entries) {
      final int dayIndex = entry.key;

      if (dayIndex >= matchedSpots.length) {
        print('⚠️ 略過 Day $dayIndex，超出 tripDays 範圍 $tripDays');
        continue;
      }

      for (final gptName in entry.value) {
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
        } else {
          print('❓ 找不到對應景點：$gptName');
        }
      }
    }

    // 🧾 輸出結果
    print('✅ 匹配完成，每日景點如下：');
    for (int i = 0; i < matchedSpots.length; i++) {
      print('Day ${i + 1}: ${matchedSpots[i].map((s) => s['Name']).join(", ")}');
    }

    // 🚀 跳轉並儲存行程
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelDayPage(
          tripName: 'GPT推薦行程',
          startDate: widget.startDate!,
          endDate: widget.startDate!.add(Duration(days: matchedSpots.length - 1)),
          budget: widget.budget?.toInt() ?? 0,
          transport: widget.transport ?? '不限',
          initialSpots: matchedSpots,
          readOnly: false,
          mood: widget.mood,  // 加上這行
          need: widget.need,  // 加上這行
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
  } catch (e, stackTrace) {
    print('❌ 解析或建立行程失敗：$e');
    print(stackTrace);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ 發生錯誤'),
        content: Text('解析 GPT 行程或跳轉頁面時發生錯誤：\n$e'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('我知道了')),
        ],
      ),
    );
  }
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
            
            if ((widget.mood ?? '').trim().isNotEmpty)
              Text('🧠 GPT 已考慮您的心情：${widget.mood}'),

            if ((widget.need ?? '').trim().isNotEmpty)
              Text('🎯 GPT 已考慮您的需求：${widget.need}'),


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
