import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/travel_note_page.dart';
import 'dart:convert';
import 'travel_day_page.dart';

// ===== 全站統一：奶茶文青風色票 =====
const kBgCream     = Color(0xFFFAF3E0); // 背景：淡奶茶米色
const kCardBase    = Color(0xFFEAD7B7); // 卡片底：奶茶棕
const kPressedTint = Color(0xFFD6C2A1); // 按下/hover
const kTextDark    = Color(0xFF4E342E); // 文字：深棕
const kAccent      = Color(0xFFB48A60); // 主色：拿鐵咖啡

class MyJournalTab extends StatefulWidget {
  const MyJournalTab({super.key});

  @override
  State<MyJournalTab> createState() => _MyJournalTabState();
}

class _MyJournalTabState extends State<MyJournalTab> {
  List<Map<String, dynamic>> trips = [];

  @override
  void initState() {
    super.initState();
    _loadTripsFromStorage();
  }

  Future<void> _loadTripsFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final tripListString = prefs.getStringList('trip_list') ?? [];
    setState(() {
      trips = tripListString
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();
    });
  }

  Future<void> _saveTripsToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final tripListString = trips.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('trip_list', tripListString);
  }

  /// 檢查是否已有任何心得（行程層級 note 或 daily_spots 內的 note/notes）
  bool _hasAnyNote(Map<String, dynamic> trip) {
    final tNote = (trip['note'] is String) ? (trip['note'] as String).trim() : '';
    if (tNote.isNotEmpty) return true;

    final daily = (trip['daily_spots'] as List?) ?? const [];
    for (final day in daily) {
      for (final spot in (day as List)) {
        final m = Map<String, dynamic>.from(spot as Map);
        final s1 = (m['note'] is String) ? (m['note'] as String).trim() : '';
        final s2 = (m['notes'] is String) ? (m['notes'] as String).trim() : '';
        if (s1.isNotEmpty || s2.isNotEmpty) return true;
      }
    }
    return false;
  }

  /// 依照 readOnly 開啟心得頁：
  /// - readOnly=false：撰寫/編輯心得，返回則更新 daily_spots
  /// - readOnly=true：僅查看心得，不做更新
  void _openNotePage(int index, {required bool readOnly}) async {
    final trip = trips[index];

    final List<List<Map<String, String>>> dailySpots =
        (trip['daily_spots'] as List)
            .map<List<Map<String, String>>>(
              (day) => (day as List)
                  .map<Map<String, String>>(
                    (s) => Map<String, String>.from(s as Map),
                  )
                  .toList(),
            )
            .toList();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelNotePage(
          allDailySpots: dailySpots,
          readOnly: readOnly,
        ),
      ),
    );

    if (!readOnly && result != null && result is List<List<Map<String, String>>>) {
      setState(() {
        trips[index]['daily_spots'] = result;
      });
      _saveTripsToStorage();
    }
  }

  void _openTripDetail(Map<String, dynamic> trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelDayPage(
          tripName: trip['trip_name'],
          startDate: DateTime.parse(trip['start_date']),
          endDate: DateTime.parse(trip['end_date']),
          budget: trip['budget'],
          transport: trip['transport'],
          initialSpots: (trip['daily_spots'] as List)
              .map<List<Map<String, String>>>(
                (day) => (day as List)
                    .map<Map<String, String>>((s) => Map<String, String>.from(s))
                    .toList(),
              )
              .toList(),
          initialTransports: (trip['daily_transports'] as List)
              .map<List<String>>((list) => List<String>.from(list))
              .toList(),
          readOnly: true,
        ),
      ),
    );
  }

  Widget _buildTripList() {
    if (trips.isEmpty) {
      return const Center(
        child: Text("目前沒有任何行程", style: TextStyle(color: kTextDark)),
      );
    }

    return Container(
      color: kBgCream,
      child: ListView.builder(
        itemCount: trips.length,
        itemBuilder: (context, index) {
          final trip = trips[index];
          final hasNote = _hasAnyNote(trip);

          return GestureDetector(
            onTap: () => _openTripDetail(trip),
            child: Card(
              color: kCardBase, // ✅ 奶茶色底
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip["trip_name"] ?? '未命名行程',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("📅 ${trip["start_date"]} ~ ${trip["end_date"]}",
                        style: const TextStyle(color: kTextDark)),
                    Text("💸 預算：\$${trip["budget"]}",
                        style: const TextStyle(color: kTextDark)),
                    const SizedBox(height: 8),
                    Text(
                      "✏️ 心得：${hasNote ? "已撰寫" : "尚未撰寫"}",
                      style: const TextStyle(color: kTextDark),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openNotePage(index, readOnly: hasNote),
                            icon: Icon(
                              hasNote ? Icons.visibility : Icons.edit_note,
                              color: Colors.white,
                            ),
                            label: Text(
                              hasNote ? "查看心得" : "撰寫心得",
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 1,
                            ),
                          ),
                        ),
                        // ✅ 「上傳到社群」已移除
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildTripList();
  }
}
