import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'travel_info_page.dart';
import 'travel_day_page.dart';

// ===== 文青奶茶色系統一 =====
const kBgCream     = Color(0xFFFAF3E0); // 背景：淡奶茶米色
const kCardBase    = Color(0xFFEAD7B7); // 卡片底：奶茶棕
const kPressedTint = Color(0xFFD6C2A1); // 按下 hover：更深一階
const kTextDark    = Color(0xFF4E342E); // 文字：深棕
const kAccent      = Color(0xFFB48A60); // 點綴：拿鐵咖啡色

class TravelInputPage extends StatefulWidget {
  final int initialTabIndex;
  const TravelInputPage({super.key, this.initialTabIndex = 0});

  @override
  State<TravelInputPage> createState() => _TravelInputPageState();
}

class _TravelInputPageState extends State<TravelInputPage> with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> trips = [];
  Map<String, List<Map<String, String>>> favoritesByCity = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _loadTripsFromStorage();
    _loadFavorites();
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

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorite_spots') ?? [];
    final favorites = favList.map((e) => Map<String, String>.from(jsonDecode(e))).toList();

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
        builder: (_) => TravelDayPage(
          tripName: trip['trip_name'],
          startDate: DateTime.parse(trip['start_date']),
          endDate: DateTime.parse(trip['end_date']),
          budget: trip['budget'],
          transport: trip['transport'],
          initialSpots: (trip['daily_spots'] as List)
              .map<List<Map<String, String>>>((day) => (day as List)
              .map<Map<String, String>>((s) => Map<String, String>.from(s)).toList()).toList(),
          initialTransports: (trip['daily_transports'] as List)
              .map<List<String>>((tList) => (tList as List).map<String>((t) => t.toString()).toList()).toList(),
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        trips[index] = result;
      });
      _loadFavorites();
    }
  }

  void _viewTrip(int index) {
    final trip = trips[index];
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
              .map<List<Map<String, String>>>((day) => (day as List)
              .map<Map<String, String>>((s) => Map<String, String>.from(s)).toList()).toList(),
          initialTransports: (trip['daily_transports'] as List)
              .map<List<String>>((tList) => (tList as List).map<String>((t) => t.toString()).toList()).toList(),
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
    final infoResult = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TravelInfoInputPage()),
    );

    if (infoResult == null || infoResult is! Map<String, dynamic>) return;

    final startDate = DateTime.parse(infoResult['start_date']);
    final endDate = DateTime.parse(infoResult['end_date']);

    final tripResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelDayPage(
          tripName: infoResult['trip_name'],
          startDate: startDate,
          endDate: endDate,
          budget: infoResult['budget'],
          transport: infoResult['transport'],
          initialSpots: [],
          initialTransports: [],
          readOnly: false,
        ),
      ),
    );

    if (tripResult != null && tripResult is Map<String, dynamic>) {
      setState(() {
        trips.add(tripResult);
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
        child: Text("目前沒有旅遊規劃紀錄", style: TextStyle(fontSize: 16, color: kTextDark)),
      );
    }

    return ListView.builder(
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return InkWell(
          onTap: () => _viewTrip(index),
          child: Card(
            color: kCardBase,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                color: kTextDark,
                              ),
                            ),
                            Text("${trip["trip_type"] ?? '自訂'}",
                                style: const TextStyle(color: kTextDark)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: kAccent),
                            onPressed: () => _editTrip(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _deleteTrip(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("📅 ${trip["start_date"]} ~ ${trip["end_date"]}",
                      style: const TextStyle(color: kTextDark)),
                  Text("💸 預算：\$${trip["budget"]}",
                      style: const TextStyle(color: kTextDark)),
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
        child: Text("目前沒有收藏的景點", style: TextStyle(fontSize: 16, color: kTextDark)),
      );
    }

    return ListView(
      children: favoritesByCity.entries.map((entry) {
        final city = entry.key;
        final spots = entry.value;
        return ExpansionTile(
          backgroundColor: kCardBase.withOpacity(0.7),
          collapsedBackgroundColor: kCardBase,
          title: Text(city,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: kTextDark)),
          children: spots.map((spot) {
            return ListTile(
              leading: const Icon(Icons.place, color: kAccent),
              title: Text(spot['Name'] ?? '無名稱',
                  style: const TextStyle(color: kTextDark)),
              subtitle:
                  Text(spot['Add'] ?? '（無地址）', style: const TextStyle(color: kTextDark)),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
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
    return Scaffold(
      backgroundColor: kBgCream,
      appBar: AppBar(
        backgroundColor: kBgCream,
        elevation: 0,
        title: const Text("🗂 我的行程與收藏",
            style: TextStyle(color: kTextDark, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kAccent,
          labelColor: kTextDark,
          unselectedLabelColor: kTextDark,
          tabs: const [
            Tab(text: "行程規劃"),
            Tab(text: "我的收藏"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Padding(padding: const EdgeInsets.all(16), child: _buildTripList()),
          Padding(padding: const EdgeInsets.all(16), child: _buildFavoriteSpots()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTrip,
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        label: const Text("新增行程"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
