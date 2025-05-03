import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FavoritesSpotPage extends StatefulWidget {
  const FavoritesSpotPage({super.key});

  @override
  State<FavoritesSpotPage> createState() => _FavoritesSpotPageState();
}

class _FavoritesSpotPageState extends State<FavoritesSpotPage> {
  Map<String, List<Map<String, String>>> cityGroupedSpots = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorite_spots') ?? [];
    final spots = favList.map((e) => Map<String, String>.from(jsonDecode(e))).toList();

    // 根據 Region 分組
    final Map<String, List<Map<String, String>>> grouped = {};
    for (var spot in spots) {
      final city = spot['Region'] ?? '其他';
      if (!grouped.containsKey(city)) {
        grouped[city] = [];
      }
      grouped[city]!.add(spot);
    }

    setState(() {
      cityGroupedSpots = grouped;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收藏景點')),
      body: cityGroupedSpots.isEmpty
          ? const Center(child: Text('尚無收藏景點'))
          : ListView(
              children: cityGroupedSpots.entries.map((entry) {
                final city = entry.key;
                final spots = entry.value;
                return ExpansionTile(
                  title: Text(city, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: spots.map((spot) {
                    return ListTile(
                      title: Text(spot['Name'] ?? '無名稱'),
                      subtitle: Text(spot['Add'] ?? '無地址'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // 可擴充點進後的詳細資訊或導航
                      },
                    );
                  }).toList(),
                );
              }).toList(),
            ),
    );
  }
}
