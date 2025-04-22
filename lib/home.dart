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

  // final List<String> _images = [
  //   'assets/images/jiufen.jpg',
  //   'assets/images/SunSet.jpg',
  //   'assets/images/Alishan.jpg',
  // ];

  @override
  void initState() {
    super.initState();
  //  _startAutoSlide();
  }

  // void _startAutoSlide() {
  //   Future.delayed(const Duration(seconds: 3), () {
  //     if (!mounted) return;
  //     setState(() {
  //       _currentPage = (_currentPage + 1) % _images.length;
  //       _pageController.animateToPage(
  //         _currentPage,
  //         duration: const Duration(milliseconds: 500),
  //         curve: Curves.easeInOut,
  //       );
  //     });
  //     _startAutoSlide();
  //   });
  // }

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
      builder:
          (_) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  options.entries.map((entry) {
                    return ListTile(
                      title: Text(entry.key),
                      onTap: () => _launchURL(entry.value),
                    );
                  }).toList(),
            ),
          ),
    );
  }

  Widget _buildServiceButton(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF7F7F7),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 輪播圖加回來
          // ClipRRect(
          //   borderRadius: BorderRadius.circular(15),
          //   child: SizedBox(
          //     height: 180,
          //     width: double.infinity,
          //     child: PageView.builder(
          //       controller: _pageController,
          //       itemCount: _images.length,
          //       itemBuilder:
          //           (_, index) =>
          //               Image.asset(_images[index], fit: BoxFit.cover),
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 20),

          const Text(
            "Trip Tok",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              _buildServiceButton("交通", Icons.directions_car, () {
                _showOptionsDialog("選擇租車網站", {
                  '格上租車': 'https://www.car-plus.com.tw/',
                  '和運租車': 'https://www.easyrent.com.tw/',
                  'iRent': 'https://www.irentcar.com.tw/irent/web/',
                });
              }),
              _buildServiceButton("住宿", Icons.hotel, () {
                _showOptionsDialog("選擇訂房網站", {
                  'Agoda': 'https://www.agoda.com/zh-tw',
                  'Booking.com': 'https://www.booking.com/zh-tw/index.html',
                  'AsiaYo': 'https://asiayo.com/zh-tw/',
                });
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildServiceButton("機票", Icons.flight_takeoff, () {
                _launchURL(
                  "https://flight.eztravel.com.tw/?utm_source=google&utm_medium=ad_sem&AllianceID=201&SID=1&ouid=11811814559&gad_source=1&gbraid=0AAAAAC2qCl8DsS8YqH7xiUfYSaf94UAuI&gclid=CjwKCAjw8IfABhBXEiwAxRHlsGGYSGdalPC4ukq8y22KlnAM6_OKRDANOSwGAXLDJ6s3ZmiduAbpmxoCe7AQAvD_BwE",
                );
              }),
              _buildServiceButton("", Icons.sim_card, () {
                _launchURL("https://yoyogoshop.com/");
              }),
            ],
          ),

          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🗂 我的旅遊規劃',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text('目前沒有旅遊規劃紀錄', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _onItemTapped(2),
                  child: const Text('新增旅遊計畫'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelPlanPage() => const TravelInputPage();
  Widget _buildProfilePage() => const ProfilePage();
  Widget _buildJournalPage() => const JournalPage();
  Widget _buildExplorePage() => TravelFormPage(dayIndex: 0, browseOnly: true);

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomePage(),
      _buildExplorePage(),
      _buildTravelPlanPage(),
      _buildJournalPage(),
      _buildProfilePage(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首頁'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '探索'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '行程'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: '日誌'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '個人'),
        ],
      ),
    );
  }
}
