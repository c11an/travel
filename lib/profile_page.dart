import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

import 'setting_page.dart';
import 'follow_list_page.dart';
import 'login.dart';
import 'favorites_spot_page.dart';
import 'favorites_trip_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  File? _avatarImage;
  List<Map<String, dynamic>> uploadedTrips = [];
  List<Map<String, dynamic>> favoriteCommunityTrips = [];

  final List<String> followingUsers = ['Alice', 'Bob', 'Charlie'];
  final List<String> followerUsers = ['David', 'Emma'];

  late TabController _tabController;
  int get followingCount => followingUsers.length;
  int get followerCount => followerUsers.length;
  int favoriteSpotCount = 15;

  @override
  void initState() {
    super.initState();
    _loadUploadedTrips();
    _loadAvatarImage();
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

  Future<void> _loadAvatarImage() async {
    final prefs = await SharedPreferences.getInstance();
    final avatarPath = prefs.getString('avatarPath');
    if (avatarPath != null && File(avatarPath).existsSync()) {
      setState(() {
        _avatarImage = File(avatarPath);
      });
    }
  }

  Future<void> _pickAvatarImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatarPath', pickedFile.path);

      setState(() {
        _avatarImage = File(pickedFile.path);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 頭像更新成功！')),
        );
      }
    }
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認登出'),
        content: const Text('確定要登出嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginPage(),
            settings: const RouteSettings(arguments: 'logged_out'),
          ),
          (route) => false,
        );
      }
    }
  }

  void _goToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingPage()),
    );
  }

  void _openFollowList(String title, List<String> users) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowListPage(title: title, userList: users),
      ),
    );
  }

  Widget _buildFavoriteBlock(String title, IconData icon, Color color, Widget page) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
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
                GestureDetector(
                  onTap: () => _openFollowList('我追蹤的人', followingUsers),
                  child: Text('追蹤中：$followingCount', style: const TextStyle(fontSize: 16)),
                ),
                GestureDetector(
                  onTap: () => _openFollowList('粉絲列表', followerUsers),
                  child: Text('粉絲數：$followerCount', style: const TextStyle(fontSize: 16)),
                ),
              ],
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
                  Column(
                    children: [
                      Row(
                        children: [
                          _buildFavoriteBlock('收藏景點', Icons.place, Colors.lightBlue, const FavoritesSpotPage()),
                          const SizedBox(width: 16),
                          _buildFavoriteBlock('收藏行程', Icons.map, Colors.orange, const FavoritesTripPage()),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
          ),
        );
      },
    );
  }
}
