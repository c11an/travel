import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:travel/travel_day_page.dart'; // ⭐記得import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/personalization_controller.dart'; // 第4/5步控制器
import 'package:travel/api.dart';                        // 你先前建的 ApiClient

// ===== 全站統一：奶茶文青風配色 =====
const kBgCream     = Color(0xFFFAF3E0); // 背景：淡奶茶米色
const kCardBase    = Color(0xFFEAD7B7); // 卡片底：奶茶棕
const kPressedTint = Color(0xFFD6C2A1); // 按下 hover
const kTextDark    = Color(0xFF4E342E); // 深棕文字
const kAccent      = Color(0xFFB48A60); // 拿鐵咖啡主色

class AIRecommendResultPage extends StatefulWidget {
  final String? city;
  final double? budget;
  final String? transport;
  final List<String>? types;
  final String tripName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? gptRecommendation;
  final String? mood;
  final String? need;
  final List<Map<String, String>> allSpots; // 🔧 新增
  
  


  const AIRecommendResultPage({
    super.key,
    required this.tripName,
    required this.allSpots,
    this.city,
    this.budget,
    this.transport,
    this.types,
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
  
  late final PersonalizationController p;
  final api = ApiClient();
  String? _uid;



  @override
  void initState() {
    super.initState();
    p = PersonalizationController();
    p.init();          // 載入上次的全域權重（若有）
    _ensureUid();      // 產生並保存一個穩定的 client id
    print('🧠 mood: ${widget.mood}, 🎯 need: ${widget.need}');
    //_loadRecommendedSpots();
  }

  //void _loadRecommendedSpots() {
  //  setState(() {
  //    recommendedSpots = widget.spots.map((spot) {
  //      return {
  //        'name': spot['Name'] ?? '',
  //        'type': spot['Category'] ?? '',
  //        'location': spot['Region'] ?? '',
  //        'imageUrl': spot['Picture1'] ?? '',
  //        'rating': 4.5,
  //        'description': spot['Description'] ?? '沒有描述',
  //      };
  //    }).toList();
  //  });
  //}

  Future<void> _ensureUid() async {
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString('uid');
    if (_uid == null) {
      _uid = 'device-${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('uid', _uid!);
    }
  }

  

  void _convertGptToTravelPage() async {
    debugPrint("📊 allSpots.first 內容: ${widget.allSpots.isNotEmpty ? widget.allSpots.first : '空的'}");
    final Map<int, List<Map<String, String>>> dayMap = {};
    List<List<Map<String, String>>> matchedSpots = [];

    try {
      final gptText = widget.gptRecommendation ?? '';

      if (widget.startDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ 未設定旅遊起始日期')),
        );
        return;
      }

      // 若使用者未選 endDate，但 GPT 有多天，我們會用解析結果補足；反之如果有 endDate 就尊重使用者
      final hasUserEndDate = widget.endDate != null;

      if (gptText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ GPT 回傳內容為空')),
        );
        return;
      }

      // 🧠 解析 GPT 內容 → dayMap
      final lines = gptText.split('\n');
      int currentDay = -1;
      String? currentTime;

      for (var raw in lines) {
        var line = raw.trim();
        if (line.isEmpty) continue;

        if (line.startsWith('Day')) {
          final match = RegExp(r'Day\s*(\d+)').firstMatch(line);
          if (match != null) {
            currentDay = int.parse(match.group(1)!) - 1;
            dayMap[currentDay] = [];
          }
        } else if (RegExp(r'^\d{2}:\d{2}\s*~\s*\d{2}:\d{2}$').hasMatch(line)) {
          currentTime = line;
        } else if (line.startsWith('景點：') && currentDay >= 0 && currentTime != null) {
          final name = line.replaceFirst('景點：', '').trim();
          dayMap[currentDay]?.add({'time': currentTime, 'name': name});
        }
      }

      if (dayMap.isEmpty) {
        throw Exception('GPT 行程內容無法解析成天數結構');
      }

      // 📅 建立每天的清單長度
      final gptMaxDay = dayMap.keys.reduce(max) + 1; // day index 0-based → +1
      final userDays = hasUserEndDate
          ? widget.endDate!.difference(widget.startDate!).inDays + 1
          : gptMaxDay;
      final tripDays = max(1, userDays);

      matchedSpots = List.generate(tripDays, (_) => <Map<String, String>>[]);

      // 📍 比對 GPT 名稱 → allSpots
      for (final entry in dayMap.entries) {
        final int dayIndex = entry.key;
        if (dayIndex < 0 || dayIndex >= matchedSpots.length) continue; // 超出使用者天數就忽略

        for (final item in entry.value) {
          final gptName = item['name']!;
          final timeSlot = item['time']!;
          Map<String, String>? bestSpot;

          for (final spot in widget.allSpots) {
            final spotName = spot['Name'] ?? '';
            String normalize(String s) => s.replaceAll(' ', '').toLowerCase();
            if (normalize(spotName).contains(normalize(gptName)) ||
                normalize(gptName).contains(normalize(spotName))) {
              bestSpot = {...spot, 'TimeSlot': timeSlot};
              break;
            }
          }

          if (bestSpot != null) {
            final parts = timeSlot.split('~');
            if (parts.length == 2) {
              final start = parts[0].trim();
              final end = parts[1].trim();
              final startHour = int.tryParse(start.split(':').first);
              final endHour = int.tryParse(end.split(':').first);
              if (startHour != null && endHour != null && endHour > startHour) {
                bestSpot['Time'] = startHour.toString().padLeft(2, '0');
                bestSpot['Duration'] = (endHour - startHour).toString();
                debugPrint("Day $dayIndex >> ${bestSpot['Name']} at ${bestSpot['Time']} for ${bestSpot['Duration']}h");
              } else {
                // 無效時段 → 給預設
                bestSpot['Time'] = '08';
                bestSpot['Duration'] = '1';
              }
            }
            matchedSpots[dayIndex].add(bestSpot);
          } else {
            debugPrint('❓ 找不到對應景點：$gptName');
          }
        }
      }

      // ✅ 依時間排序
      for (var day in matchedSpots) {
        day.sort((a, b) {
          final ta = (a['TimeSlot'] ?? '').compareTo(b['TimeSlot'] ?? '');
          if (ta != 0) return ta;
          final ha = int.tryParse(a['Time'] ?? '0') ?? 0;
          final hb = int.tryParse(b['Time'] ?? '0') ?? 0;
          return ha.compareTo(hb);
        });
      }

      // 🔁（選用）本機 re-rank（不上傳）
      final budget = widget.budget ?? 0;
      final prefers = widget.types ?? const <String>[];
      for (int i = 0; i < matchedSpots.length; i++) {
        matchedSpots[i] = p.reRankCandidates(
          matchedSpots[i],
          budget: budget,
          typesPrefer: prefers,
        );
      }

      // 🧠（選用）紀錄本機回饋（不上傳）
      final positive = <Map<String, String>>[];
      for (final day in matchedSpots) {
        positive.addAll(day);
      }
      final chosenNames = positive.map((e) => e['Name']).whereType<String>().toSet();
      final negative = widget.allSpots
          .where((s) => !chosenNames.contains(s['Name']))
          .take(positive.length.clamp(0, 30))
          .toList();

      for (final s in positive) {
        p.feedbackPositive(s, budget: budget, typesPrefer: prefers);
      }
      for (final s in negative) {
        p.feedbackNegative(s, budget: budget, typesPrefer: prefers);
      }

      // 🆕 立刻在本地訓練，並輸出明確的訓練 log（不打網路）
      try {
        debugPrint('🧪 call trainLocalOnly...');
        await p.trainLocalOnly(); // 這裡會觸發 LRModel.train() 內的 🚀/✅ log
        await p.maybeTrainAndUpload(api: api, uid: _uid ?? 'local', round: 1);
        debugPrint('🏁 trainLocalOnly finished');
      } catch (e) {
        debugPrint('⚠️ trainLocalOnly 發生錯誤：$e');
      }

      // 🚀 跳轉頁面（只帶資料，不上傳）
      final DateTime finalEndDate = hasUserEndDate
          ? widget.endDate!
          : widget.startDate!.add(Duration(days: matchedSpots.length - 1));

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TravelDayPage(
            tripName: widget.tripName,
            startDate: widget.startDate!,
            endDate: finalEndDate,
            budget: widget.budget?.toInt() ?? 0,
            transport: widget.transport ?? '不限',
            initialSpots: matchedSpots,
            readOnly: false,
            mood: widget.mood,
            need: widget.need,
            fromAiResult: true,     
          ),
        ),
      ).then((result) async {
        // 不上傳；真正的上傳在 TravelDayPage 的「儲存」按鈕
      });

    } catch (e, stackTrace) {
      debugPrint('❌ 解析或建立行程失敗：$e');
      debugPrint(stackTrace.toString());
      showDialog(
        context: context,
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kAccent,
              onPrimary: Colors.white,
              surface: kCardBase,
              onSurface: kTextDark,
            ),
          ),
          child: AlertDialog(
            backgroundColor: kCardBase,
            title: const Text('⚠️ 發生錯誤', style: TextStyle(color: kTextDark, fontWeight: FontWeight.bold)),
            content: Text('解析 GPT 行程或跳轉頁面時發生錯誤：\n$e',
                style: const TextStyle(color: kTextDark)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('我知道了', style: TextStyle(color: kAccent)),
              ),
            ],
          ),
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
      backgroundColor: kBgCream,
      appBar: AppBar(
        backgroundColor: kBgCream,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextDark),
        title: const Text(
          'AI推薦結果',
          style: TextStyle(color: kTextDark, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 推薦條件簡述
            Text('行程名稱：${widget.tripName}', style: const TextStyle(color: kTextDark)),
            Text('出發地：${widget.city ?? "未指定"}', style: const TextStyle(color: kTextDark)),
            if (widget.startDate != null && widget.endDate != null)
              Text(
                '旅遊時間：${DateFormat('yyyy/MM/dd').format(widget.startDate!)} ~ ${DateFormat('yyyy/MM/dd').format(widget.endDate!)}',
               style: const TextStyle(color: kTextDark))

            else
              const Text('旅遊時間：未指定', style: const TextStyle(color: kTextDark)),
              Text('預算：${widget.budget?.round() ?? 0} 元', style: const TextStyle(color: kTextDark)),
              //Text('交通方式：${widget.transport ?? "不限"}'),
              Text('旅遊類型：${widget.types?.join(', ') ?? "不限"}', style: const TextStyle(color: kTextDark)),
              const SizedBox(height: 16),
            
            if ((widget.mood ?? '').trim().isNotEmpty)
              Text('🧠 GPT 已考慮您的心情：${widget.mood}', style: const TextStyle(color: kTextDark)),

            if ((widget.need ?? '').trim().isNotEmpty)
              Text('🎯 GPT 已考慮您的需求：${widget.need}', style: const TextStyle(color: kTextDark)),


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
                  color: kCardBase.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
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
                    icon: const Icon(Icons.calendar_month, color: Colors.white),
                    label: const Text('查看AI推薦行程', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.refresh, color: kTextDark),
                    label: const Text('重新推薦', style: TextStyle(color: kTextDark)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kCardBase.withOpacity(0.8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
