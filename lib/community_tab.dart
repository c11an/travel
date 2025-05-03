import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'travel_day_page.dart';

class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key});

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab> {
  List<Map<String, dynamic>> communityTrips = [];

  @override
  void initState() {
    super.initState();
    _loadCommunityTrips();
  }

  Future<void> _loadCommunityTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final communityList = prefs.getStringList('community_trips') ?? [];

    final tripsFromStorage = communityList.map((e) {
      final decoded = jsonDecode(e) as Map<String, dynamic>;
      decoded['comments'] = decoded['comments'] ?? <String>[];
      return decoded;
    }).toList();

    setState(() {
      communityTrips = [
        {
          'trip_name': '台中三日遊',
          'author': '旅人A',
          'note': '這次旅程去了高美濕地與彩虹眷村，非常推薦！',
          'start_date': '2024-05-01',
          'end_date': '2024-05-03',
          'budget': 5000,
          'trip_type': '推薦行程',
          'daily_spots': [],
          'daily_transports': [],
          'comments': ['看起來超棒的！', '我也想去～'],
        },
        {
          'trip_name': '花蓮自然行',
          'author': '旅人B',
          'note': '清水斷崖風景超美，太魯閣也很好玩！',
          'start_date': '2024-04-10',
          'end_date': '2024-04-12',
          'budget': 6000,
          'trip_type': '自然探索',
          'daily_spots': [],
          'daily_transports': [],
          'comments': ['太魯閣真的很壯觀！'],
        },
        ...tripsFromStorage,
      ];
    });
  }

  void _addComment(int index, String comment) {
    setState(() {
      communityTrips[index]['comments'].add(comment);
    });
  }

  void _showCommentDialog(int index) {
    String newComment = '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('留言'),
        content: TextField(
          onChanged: (value) => newComment = value,
          decoration: const InputDecoration(hintText: '輸入留言...'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (newComment.trim().isNotEmpty) {
                _addComment(index, newComment.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('送出'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToMyTrips(Map<String, dynamic> trip) async {
    final prefs = await SharedPreferences.getInstance();

    // 儲存到 trip_list
    final List<String> tripListString = prefs.getStringList('trip_list') ?? [];
    final bool existsInTripList = tripListString.any((t) {
      final decoded = jsonDecode(t);
      return decoded['trip_name'] == trip['trip_name'] &&
            decoded['start_date'] == trip['start_date'];
    });

    if (!existsInTripList) {
      tripListString.add(jsonEncode(trip));
      await prefs.setStringList('trip_list', tripListString);
    }

    // 儲存到 favorite_community_trips
    final List<String> favoriteList = prefs.getStringList('favorite_community_trips') ?? [];
    final bool existsInFavorites = favoriteList.any((t) {
      final decoded = jsonDecode(t);
      return decoded['trip_name'] == trip['trip_name'] &&
            decoded['start_date'] == trip['start_date'];
    });

    if (!existsInFavorites) {
      favoriteList.add(jsonEncode(trip));
      await prefs.setStringList('favorite_community_trips', favoriteList);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ 已成功收藏到我的行程與收藏行程')),
    );
  }



  void _openTripDetail(Map<String, dynamic> trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelDayPage(
          tripName: trip["trip_name"],
          startDate: DateTime.parse(trip["start_date"]),
          endDate: DateTime.parse(trip["end_date"]),
          budget: trip["budget"],
          transport: trip["transport"] ?? '未指定',
          initialSpots: (trip['daily_spots'] as List)
              .map<List<Map<String, String>>>((d) =>
                  (d as List).map<Map<String, String>>((s) => Map<String, String>.from(s)).toList())
              .toList(),
          initialTransports: (trip['daily_transports'] as List)
              .map<List<String>>((d) =>
                  (d as List).map<String>((s) => s.toString()).toList())
              .toList(),
          readOnly: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: communityTrips.length,
      itemBuilder: (context, index) {
        final trip = communityTrips[index];
        return GestureDetector(
          onTap: () => _openTripDetail(trip),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip['trip_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('作者：${trip['author'] ?? '匿名'}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('📅 ${trip["start_date"]} ~ ${trip["end_date"]}'),
                  Text('💸 預算：\$${trip["budget"]}'),
                  const SizedBox(height: 8),
                  Text('📝 心得：${trip['note'] ?? "無"}'),
                  const SizedBox(height: 8),
                  Text('💬 留言：'),
                  if ((trip['comments'] as List).isEmpty)
                    const Text("尚無留言", style: TextStyle(color: Colors.grey)),
                  ...trip['comments'].map<Widget>((c) => Text('• $c')).toList(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.comment, color: Colors.blue),
                        onPressed: () => _showCommentDialog(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark_add, color: Colors.green),
                        onPressed: () => _saveToMyTrips(trip),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
