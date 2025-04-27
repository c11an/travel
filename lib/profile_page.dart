import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

import 'travel_input_page.dart';
import 'travel_day_page.dart';
import 'setting_page.dart'; // 新增 import

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  File? _avatarImage;
  List<Map<String, dynamic>> uploadedTrips = [];
  List<Map<String, dynamic>> favoriteCommunityTrips = [];

  late TabController _tabController;
  int followingCount = 10;
  int followerCount = 25;
  int favoriteSpotCount = 15;

  @override
  void initState() {
    super.initState();
    _loadUploadedTrips();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _loadUploadedTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final communityList = prefs.getStringList('community_trips') ?? [];
    final favoriteCommunityList = prefs.getStringList('favorite_community_trips') ?? [];

    setState(() {
      uploadedTrips = communityList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      favoriteCommunityTrips = favoriteCommunityList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _pickAvatarImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _avatarImage = File(pickedFile.path);
      });
    }
  }

  void _goToMyFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TravelInputPage(initialTabIndex: 1)),
    );
  }

  void _goToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingPage()),
    );
  }

  void _openTripDetail(Map<String, dynamic> trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TravelDayPage(
          tripName: trip["trip_name"],
          startDate: DateTime.parse(trip["start_date"]),
          endDate: DateTime.parse(trip["end_date"]),
          budget: trip["budget"],
          transport: trip["transport"] ?? '未指定',
          initialSpots: (trip['daily_spots'] as List)
              .map<List<Map<String, String>>>((d) => (d as List)
              .map<Map<String, String>>((s) => Map<String, String>.from(s)).toList()).toList(),
          initialTransports: (trip['daily_transports'] as List)
              .map<List<String>>((d) => (d as List).map<String>((s) => s.toString()).toList()).toList(),
          readOnly: true,
        ),
      ),
    );
  }

  Widget _buildTripList(List<Map<String, dynamic>> trips) {
    if (trips.isEmpty) {
      return const Center(child: Text('尚無行程'));
    }

    return ListView.builder(
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.flight_takeoff, color: Colors.blueAccent),
            title: Text(trip['trip_name'] ?? '未命名行程'),
            subtitle: Text('📅 ${trip['start_date']} ~ ${trip['end_date']}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openTripDetail(trip),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('個人頁面'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _goToSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _pickAvatarImage,
                  child: CircleAvatar(
                    radius: 35,
                    backgroundImage: _avatarImage != null ? FileImage(_avatarImage!) : null,
                    child: _avatarImage == null ? const Icon(Icons.person, size: 35) : null,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('使用者名稱', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('帳號資訊'),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('追蹤中：$followingCount', style: const TextStyle(fontSize: 16)),
                Text('粉絲數：$followerCount', style: const TextStyle(fontSize: 16)),
              ],
            ),

            const SizedBox(height: 16),

            GestureDetector(
              onTap: _goToMyFavorites,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('⭐ 已收藏景點數：$favoriteSpotCount', style: const TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '我的上傳'),
                Tab(text: '我的收藏'),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTripList(uploadedTrips),
                  _buildTripList(favoriteCommunityTrips),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
