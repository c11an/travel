import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/travel_form_page.dart';
import 'dart:convert';

import 'travel_info_page.dart';
import 'travel_day_page.dart';

class TravelInputPage extends StatefulWidget {
  const TravelInputPage({super.key});

  @override
  State<TravelInputPage> createState() => _TravelInputPageState();
}

class _TravelInputPageState extends State<TravelInputPage> {
  List<Map<String, dynamic>> trips = [];
  Map<String, List<Map<String, String>>> favoritesByCity = {};

  @override
  void initState() {
    super.initState();
    _loadTripsFromStorage();
    _loadFavorites();
  }

  Future<void> _loadTripsFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final tripListString = prefs.getStringList('trip_list') ?? [];
    setState(() {
      trips =
          tripListString
              .map((e) => jsonDecode(e) as Map<String, dynamic>)
              .toList();
    });
  }

  Future<void> _saveTripsToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final tripListString = trips.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('trip_list', tripListString);
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorite_spots') ?? [];
    final favorites =
        favList.map((e) => Map<String, String>.from(jsonDecode(e))).toList();

    final Map<String, List<Map<String, String>>> grouped = {};
    for (var spot in favorites) {
      final city = spot['Region'] ?? '未分類';
      grouped.putIfAbsent(city, () => []).add(spot);
    }

    setState(() {
      favoritesByCity = grouped;
    });
  }

  void _editTrip(int index) async {
    final trip = trips[index];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => TravelDayPage(
              tripName: trip['trip_name'],
              startDate: DateTime.parse(trip['start_date']),
              endDate: DateTime.parse(trip['end_date']),
              budget: trip['budget'],
              transport: trip['transport'],
              initialSpots:
                  (trip['daily_spots'] as List)
                      .map<List<Map<String, String>>>(
                        (day) =>
                            (day as List)
                                .map<Map<String, String>>(
                                  (s) => Map<String, String>.from(s),
                                )
                                .toList(),
                      )
                      .toList(),
              initialTransports:
                  (trip['daily_transports'] as List)
                      .map<List<String>>(
                        (tList) =>
                            (tList as List)
                                .map<String>((t) => t.toString())
                                .toList(),
                      )
                      .toList(),
            ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        trips[index] = result;
      });
      _saveTripsToStorage();
      _loadFavorites(); // 更新收藏
    }
  }

  void _viewTrip(int index) {
    final trip = trips[index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => TravelDayPage(
              tripName: trip['trip_name'],
              startDate: DateTime.parse(trip['start_date']),
              endDate: DateTime.parse(trip['end_date']),
              budget: trip['budget'],
              transport: trip['transport'],
              initialSpots:
                  (trip['daily_spots'] as List)
                      .map<List<Map<String, String>>>(
                        (day) =>
                            (day as List)
                                .map<Map<String, String>>(
                                  (s) => Map<String, String>.from(s),
                                )
                                .toList(),
                      )
                      .toList(),
              initialTransports:
                  (trip['daily_transports'] as List)
                      .map<List<String>>(
                        (tList) =>
                            (tList as List)
                                .map<String>((t) => t.toString())
                                .toList(),
                      )
                      .toList(),
              readOnly: true,
            ),
      ),
    );
  }

  void _deleteTrip(int index) async {
    setState(() {
      trips.removeAt(index);
    });
    _saveTripsToStorage();
  }

  void _addTrip() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TravelInfoInputPage()),
    );

    if (result != null && result is Map<String, dynamic>) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TravelFormPage(initialData: result)),
      ).then((finalTripData) {
        if (finalTripData != null && finalTripData is Map<String, dynamic>) {
          setState(() {
            trips.add(finalTripData); // ✅ 這邊就不會報錯了
          });
          _saveTripsToStorage();
          _loadFavorites();
        }
      });
    }
  }

  Future<void> _removeFavorite(Map<String, String> spotToRemove) async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorite_spots') ?? [];

    favList.removeWhere((e) {
      final spot = jsonDecode(e);
      return spot['Name'] == spotToRemove['Name'];
    });

    await prefs.setStringList('favorite_spots', favList);
    _loadFavorites();
  }

  Widget _buildTripList() {
    if (trips.isEmpty) {
      return const Center(
        child: Text(
          "目前沒有旅遊規劃紀錄",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return InkWell(
          onTap: () => _viewTrip(index),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip["trip_name"]?.toString().isNotEmpty == true
                                  ? trip["trip_name"]
                                  : '未命名行程',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "${trip["trip_type"] ?? '自訂'}",
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editTrip(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTrip(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("📅 ${trip["start_date"]} ~ ${trip["end_date"]}"),
                  Text("💸 預算：\$${trip["budget"]}"),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoriteSpots() {
    if (favoritesByCity.isEmpty) {
      return const Center(
        child: Text(
          "目前沒有收藏的景點",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView(
      children:
          favoritesByCity.entries.map((entry) {
            final city = entry.key;
            final spots = entry.value;

            return ExpansionTile(
              title: Text(
                city,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              children:
                  spots.map((spot) {
                    return ListTile(
                      leading: const Icon(
                        Icons.place,
                        color: Colors.deepPurple,
                      ),
                      title: Text(spot['Name'] ?? '無名稱'),
                      subtitle: Text(spot['Add'] ?? '（無地址）'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeFavorite(spot),
                      ),
                    );
                  }).toList(),
            );
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("🗂 我的行程與收藏"),
          bottom: const TabBar(tabs: [Tab(text: "行程規劃"), Tab(text: "我的收藏")]),
        ),
        body: TabBarView(
          children: [
            Padding(padding: const EdgeInsets.all(16), child: _buildTripList()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFavoriteSpots(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addTrip,
          icon: const Icon(Icons.add),
          label: const Text("新增行程"),
        ),
      ),
    );
  }
}
