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
      trips = tripListString.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _saveTripsToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final tripListString = trips.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('trip_list', tripListString);
  }

  void _openNotePage(int index) async {
    final trip = trips[index];
    final List<List<Map<String, String>>> dailySpots =
        (trip['daily_spots'] as List)
            .map<List<Map<String, String>>>((day) =>
                (day as List).map<Map<String, String>>((s) => Map<String, String>.from(s)).toList())
            .toList();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelNotePage(
          allDailySpots: dailySpots,
          readOnly: false,
        ),
      ),
    );

    if (result != null && result is List<List<Map<String, String>>>) {
      setState(() {
        trips[index]['daily_spots'] = result;
      });
      _saveTripsToStorage();
    }
  }

  Future<void> _uploadToCommunity(Map<String, dynamic> trip) async {
    final prefs = await SharedPreferences.getInstance();
    final communityList = prefs.getStringList('community_trips') ?? [];

    bool exists = communityList.any((e) {
      final decoded = jsonDecode(e);
      return decoded["trip_name"] == trip["trip_name"] &&
             decoded["start_date"] == trip["start_date"];
    });

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kPressedTint,
          content: const Text("⚠️ 此行程已經上傳過囉！", style: TextStyle(color: Colors.white)),
        ),
      );
    } else {
      communityList.add(jsonEncode(trip));
      await prefs.setStringList('community_trips', communityList);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kAccent,
          content: const Text("✅ 成功上傳到社群！", style: TextStyle(color: Colors.white)),
        ),
      );
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
                  (day) => (day as List).map<Map<String, String>>((s) => Map<String, String>.from(s)).toList())
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
                      "✏️ 心得：${trip["note"]?.isNotEmpty == true ? trip["note"] : "尚未撰寫"}",
                      style: const TextStyle(color: kTextDark),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openNotePage(index),
                            icon: const Icon(Icons.edit_note, color: Colors.white),
                            label: const Text("撰寫心得",
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _uploadToCommunity(trip),
                            icon: const Icon(Icons.upload, color: Colors.white),
                            label: const Text("上傳到社群",
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPressedTint,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 1,
                            ),
                          ),
                        ),
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
