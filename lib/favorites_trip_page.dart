import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FavoritesTripPage extends StatefulWidget {
  const FavoritesTripPage({super.key});

  @override
  State<FavoritesTripPage> createState() => _FavoritesTripPageState();
}

class _FavoritesTripPageState extends State<FavoritesTripPage> {
  List<Map<String, dynamic>> favoriteTrips = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorite_community_trips') ?? [];
    setState(() {
      favoriteTrips = favList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _removeTrip(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorite_community_trips') ?? [];

    // 找出並移除該行程
    final tripJson = jsonEncode(favoriteTrips[index]);
    favList.removeWhere((item) => item == tripJson);

    await prefs.setStringList('favorite_community_trips', favList);

    setState(() {
      favoriteTrips.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ 已取消收藏')),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收藏行程')),
      body: favoriteTrips.isEmpty
          ? const Center(child: Text('尚無收藏行程'))
          : ListView.builder(
              itemCount: favoriteTrips.length,
              itemBuilder: (context, index) {
                final trip = favoriteTrips[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.flight_takeoff, color: Colors.blueAccent),
                    title: Text(trip['trip_name'] ?? '未命名行程'),
                    subtitle: Text('📅 ${trip['start_date']} ~ ${trip['end_date']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeTrip(index),
                    ),
                  ),
                );
              },
            ),
    );
  }

}
