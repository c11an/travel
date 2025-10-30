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

// ===== 文青奶茶色系（與其他頁一致）=====
const kBgCream     = Color(0xFFFAF3E0); // 背景：淡奶茶米色
const kCardBase    = Color(0xFFEAD7B7); // 卡片/區塊底：奶茶棕
const kPressedTint = Color(0xFFD6C2A1); // 按下/hover
const kTextDark    = Color(0xFF4E342E); // 文字：深棕
const kAccent      = Color(0xFFB48A60); // 主色：拿鐵咖啡

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
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _loadUploadedTrips();
    _loadAvatarImage();
    _loadNickname();
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
      setState(() => _avatarImage = File(pickedFile.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 頭像更新成功！')),
        );
      }
    }
  }

  Future<void> _loadNickname() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nickname = prefs.getString('nickname') ?? '旅人';
    });
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認登出'),
        content: const Text('確定要登出嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定')),
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
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingPage()));
  }

  void _openFollowList(String title, List<String> users) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => FollowListPage(title: title, userList: users)));
  }

  Widget _buildFavoriteBlock(String title, IconData icon, Color bg, Widget page) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        child: Container(
          height: 100,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
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
      backgroundColor: kBgCream,
      appBar: AppBar(
        backgroundColor: kBgCream,
        elevation: 0,
        title: const Text('個人頁面',
            style: TextStyle(color: kTextDark, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: kTextDark),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _goToSettings),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kAccent,
          labelColor: kTextDark,
          unselectedLabelColor: kTextDark,
          tabs: const [Tab(text: '我的上傳'), Tab(text: '我的收藏')],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 頭像 + 暱稱
            Row(
              children: [
                GestureDetector(
                  onTap: _pickAvatarImage,
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: kCardBase,
                    backgroundImage: _avatarImage != null ? FileImage(_avatarImage!) : null,
                    child: _avatarImage == null
                        ? const Icon(Icons.person, size: 35, color: kTextDark)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nickname ?? '旅人',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
                    const Text('帳號資訊', style: TextStyle(color: kTextDark)),
                  ],
                ),
                const Spacer(),
                // 登出鈕（可選）
                TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: kAccent, size: 18),
                  label: const Text('登出', style: TextStyle(color: kAccent)),
                  style: TextButton.styleFrom(
                    foregroundColor: kAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 追蹤/粉絲
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => _openFollowList('我追蹤的人', followingUsers),
                  child: Text('追蹤中：$followingCount',
                      style: const TextStyle(fontSize: 16, color: kTextDark)),
                ),
                GestureDetector(
                  onTap: () => _openFollowList('粉絲列表', followerUsers),
                  child: Text('粉絲數：$followerCount',
                      style: const TextStyle(fontSize: 16, color: kTextDark)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tab 內容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTripList(uploadedTrips),
                  Column(
                    children: [
                      Row(
                        children: [
                          _buildFavoriteBlock('收藏景點', Icons.place, kAccent, const FavoritesSpotPage()),
                          const SizedBox(width: 16),
                          _buildFavoriteBlock('收藏行程', Icons.map, kPressedTint, const FavoritesTripPage()),
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
      return const Center(child: Text('尚無行程', style: TextStyle(color: kTextDark)));
    }

    return ListView.builder(
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return Card(
          color: kCardBase,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: const Icon(Icons.flight_takeoff, color: kAccent),
            title: Text(trip['trip_name'] ?? '未命名行程',
                style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w600)),
            subtitle: Text('📅 ${trip['start_date']} ~ ${trip['end_date']}',
                style: const TextStyle(color: kTextDark)),
            trailing: const Icon(Icons.chevron_right, color: kTextDark),
          ),
        );
      },
    );
  }
}
