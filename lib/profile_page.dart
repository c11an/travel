import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

import 'setting_page.dart';
import 'login.dart';
import 'favorites_spot_page.dart';
import 'favorites_trip_page.dart';
import 'travel_day_page.dart';

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

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  File? _avatarImage;
  List<Map<String, dynamic>> myTrips = []; // 個人行程
  late TabController _tabController;
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // ✅ 先建立
    _loadMyTrips();
    _loadAvatarImage();
    _loadNickname();
  }

  @override
  void dispose() {
    _tabController.dispose(); // ✅ 釋放，避免 _dependents.isEmpty 斷言
    super.dispose();
  }

  Future<void> _loadMyTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final tripListString = prefs.getStringList('trip_list') ?? [];
    if (!mounted) return;
    setState(() {
      myTrips = tripListString
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();
    });
  }

  Future<void> _loadAvatarImage() async {
    final prefs = await SharedPreferences.getInstance();
    final avatarPath = prefs.getString('avatarPath');
    if (!mounted) return;
    if (avatarPath != null && File(avatarPath).existsSync()) {
      setState(() => _avatarImage = File(avatarPath));
    }
  }

  Future<void> _pickAvatarImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatarPath', pickedFile.path);
      if (!mounted) return;
      setState(() => _avatarImage = File(pickedFile.path));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 頭像更新成功！')),
      );
    }
  }

  Future<void> _loadNickname() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _nickname = prefs.getString('nickname') ?? '旅人');
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
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確定')),
        ],
      ),
    );
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
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

  void _goToSettings() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SettingPage()));
  }

  DateTime _safeParseDate(dynamic v) {
    try {
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) return DateTime.parse(v);
    } catch (_) {}
    return DateTime.now();
  }

  // 點個人行程卡片 → 跳到 TravelDayPage 檢視該行程
  void _openTripDetail(Map<String, dynamic> trip) {
    final start = _safeParseDate(trip['start_date']);
    final end = _safeParseDate(trip['end_date']);

    final rawDays = (trip['daily_spots'] as List?) ?? const [];
    final initialSpots = rawDays
        .map<List<Map<String, String>>>((day) => (day as List)
            .map<Map<String, String>>(
                (s) => Map<String, String>.from(s as Map))
            .toList())
        .toList();

    final rawTrans = (trip['daily_transports'] as List?) ??
        List.generate(initialSpots.length, (_) => <String>[]);
    final initialTransports =
        rawTrans.map<List<String>>((list) => List<String>.from(list)).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelDayPage(
          tripName: (trip['trip_name'] as String?)?.trim().isNotEmpty == true
              ? trip['trip_name']
              : '未命名行程',
          startDate: start,
          endDate: end,
          budget: trip['budget'],
          transport: trip['transport'],
          initialSpots: initialSpots,
          initialTransports: initialTransports,
          readOnly: true,
        ),
      ),
    );
  }

  Widget _buildFavoriteBlock(
      String title, IconData icon, Color bg, Widget page) {
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
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
        centerTitle: true, // ✅ 置中
        title: const Text('個人頁面',
            style:
                TextStyle(color: kTextDark, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: kTextDark),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _goToSettings),
        ],
        bottom: TabBar(
          controller: _tabController, // ✅ 必須綁定
          indicatorColor: kAccent,
          labelColor: kTextDark,
          unselectedLabelColor: kTextDark,
          tabs: const [Tab(text: '我的行程'), Tab(text: '我的收藏')],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 頭像 + 暱稱 + 登出
            Row(
              children: [
                GestureDetector(
                  onTap: _pickAvatarImage,
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: kCardBase,
                    backgroundImage: _avatarImage != null
                        ? FileImage(_avatarImage!)
                        : null,
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
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kTextDark)),
                    const Text('帳號資訊',
                        style: TextStyle(color: kTextDark)),
                  ],
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: kAccent, size: 18),
                  label:
                      const Text('登出', style: TextStyle(color: kAccent)),
                  style: TextButton.styleFrom(foregroundColor: kAccent),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tab 內容
            Expanded(
              child: TabBarView(
                controller: _tabController, // ✅ 同一個 controller
                children: [
                  // 我的行程（支援下拉更新）
                  RefreshIndicator(
                    color: kAccent,
                    onRefresh: _loadMyTrips,
                    child: _buildTripList(myTrips),
                  ),
                  // 我的收藏
                  Column(
                    children: [
                      Row(
                        children: [
                          _buildFavoriteBlock('收藏景點', Icons.place, kAccent,
                              const FavoritesSpotPage()),
                          const SizedBox(width: 16),
                          _buildFavoriteBlock(
                              '收藏行程',
                              Icons.map,
                              kPressedTint,
                              const FavoritesTripPage()),
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
      // 用 ListView 包一個空畫面，確保 RefreshIndicator 可下拉
      return ListView(
        children: [
          SizedBox(height: 160),
          Center(
              child:
                  Text('尚無行程', style: TextStyle(color: kTextDark))),
        ],
      );
    }

    return ListView.builder(
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        final title = (trip['trip_name'] as String?)?.trim().isNotEmpty == true
            ? trip['trip_name'] as String
            : '未命名行程';
        final start = (trip['start_date'] ?? '').toString();
        final end = (trip['end_date'] ?? '').toString();

        return Card(
          color: kCardBase,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            onTap: () => _openTripDetail(trip), // ✅ 點擊跳轉
            leading: const Icon(Icons.flight_takeoff, color: kAccent),
            title: Text(title,
                style: const TextStyle(
                    color: kTextDark, fontWeight: FontWeight.w600)),
            subtitle: Text('📅 $start ~ $end',
                style: const TextStyle(color: kTextDark)),
            trailing:
                const Icon(Icons.chevron_right, color: kTextDark),
          ),
        );
      },
    );
  }
}
