import 'package:flutter/material.dart';
import 'package:travel/journal_page.dart';
import 'package:travel/profile_page.dart';
import 'package:travel/travel_form_page.dart';
import 'package:travel/travel_input_page.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _currentPage = 0;
  final PageController _pageController = PageController();

  final List<String> _images = [
    'assets/images/jiufen.jpg',
    'assets/images/SunSet.jpg',
    'assets/images/Alishan.jpg'
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _currentPage = (_currentPage + 1) % _images.length;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      _startAutoSlide();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw '無法打開網址: $url';
    }
  }

  void _showOptionsDialog(String title, Map<String, String> options) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.entries.map((entry) {
            return ListTile(
              title: Text(entry.key),
              onTap: () => _launchURL(entry.value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 26),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 輪播圖
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _images.length,
                itemBuilder: (_, index) => Image.asset(
                  _images[index],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('選擇您的服務', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          // 功能按鈕
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(Icons.place, '找景點', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TravelFormPage(
                      dayIndex: 0,
                      browseOnly: true,
                    ),
                  ),
                );
              }),
              _buildNavButton(Icons.car_rental, '租車 / 叫車', () {
                _showOptionsDialog('選擇租車網站', {
                  '格上租車': 'https://www.car-plus.com.tw/',
                  '和運租車': 'https://www.easyrent.com.tw/',
                  'iRent': 'https://www.irentcar.com.tw/irent/web/',
                });
              }),
              _buildNavButton(Icons.hotel, '住宿訂房', () {
                _showOptionsDialog('選擇訂房網站', {
                  'Agoda': 'https://www.agoda.com/zh-tw',
                  'Booking.com': 'https://www.booking.com/zh-tw/index.html',
                  'AsiaYo': 'https://asiayo.com/zh-tw/',
                });
              }),
            ],
          ),
          const SizedBox(height: 30),

          // 我的旅遊規劃
          _buildCardSection(
            title: '🗂 我的旅遊規劃',
            color: Colors.blue.shade100,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('目前沒有旅遊規劃紀錄', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _onItemTapped(1),
                  child: const Text('新增旅遊計劃'),
                ),
              ],
            ),
          ),

          // 推薦行程
          const SizedBox(height: 20),
          _buildCardSection(
            title: '推薦行程',
            color: const Color.fromARGB(230, 251, 222, 187),
            content: const Text('目前沒有推薦行程', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection({required String title, required Color color, required Widget content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }

  Widget _buildTravelPlanPage() => const TravelInputPage();
  Widget _buildProfilePage() => const ProfilePage();
  Widget _buildJournalPage() => const JournalPage();

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomePage(),
      _buildTravelPlanPage(),
      _buildJournalPage(),
      _buildProfilePage(),      
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Tok')),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '主頁'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '行程規劃'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: '日誌'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '個人設定'),         
        ],
      ),
    );
  }
}
