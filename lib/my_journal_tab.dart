import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'travel_day_page.dart'; // 請確認有引入

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

  void _editNoteDialog(int index) {
    final trip = trips[index];
    final TextEditingController _noteController =
        TextEditingController(text: trip["note"] ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("撰寫心得"),
        content: TextField(
          controller: _noteController,
          maxLines: 4,
          decoration: const InputDecoration(hintText: "輸入旅遊心得..."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                trips[index]["note"] = _noteController.text;
              });
              _saveTripsToStorage();
              Navigator.pop(context);
            },
            child: const Text("儲存"),
          ),
        ],
      ),
    );
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
        const SnackBar(content: Text("⚠️ 此行程已經上傳過囉！")),
      );
    } else {
      communityList.add(jsonEncode(trip));
      await prefs.setStringList('community_trips', communityList);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ 成功上傳到社群！")),
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
          readOnly: true, // ✅ 加上唯讀模式
        ),
      ),
    );
  }

  Widget _buildTripList() {
    if (trips.isEmpty) {
      return const Center(child: Text("目前沒有任何行程", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return GestureDetector(
          onTap: () => _openTripDetail(trip),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip["trip_name"] ?? '未命名行程',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text("📅 ${trip["start_date"]} ~ ${trip["end_date"]}"),
                  Text("💸 預算：\$${trip["budget"]}"),
                  const SizedBox(height: 8),
                  Text("✏️ 心得：${trip["note"]?.isNotEmpty == true ? trip["note"] : "尚未撰寫"}"),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _editNoteDialog(index),
                        icon: const Icon(Icons.edit_note),
                        label: const Text("撰寫心得"),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _uploadToCommunity(trip),
                        icon: const Icon(Icons.upload),
                        label: const Text("上傳到社群"),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildTripList();
  }
}
