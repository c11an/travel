import 'package:flutter/material.dart';
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
    Future.delayed(Duration.zero, () {
      _startAutoSlide();
    });
  }

  void _startAutoSlide() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _currentPage = (_currentPage + 1) % _images.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _startAutoSlide();
      }
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildHomePage() {
    return Container(
      color: Colors.grey[200],
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 200,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      return Image.asset(
                        _images[index],
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '選擇您的服務',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavButton(Icons.place, '找景點', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TravelFormPage(
                          dayIndex: 0,
                          browseOnly: true, // ✅ 啟用純收藏模式（無 schedule）
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🗂 我的旅遊規劃',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '目前沒有旅遊規劃紀錄',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedIndex = 1;
                        });
                      },
                      child: const Text('新增旅遊計劃'),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(230, 251, 222, 187),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '推薦行程',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '目前沒有推薦行程',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTravelPlanPage() => const TravelInputPage();

  Widget _buildProfilePage() =>
      const Center(child: Text('⚙️ 個人設定（待開發）', style: TextStyle(fontSize: 18)));

  void _showOptionsDialog(String title, Map<String, String> options) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
        );
      },
    );
  }

  Widget _buildNavButton(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 28),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomePage(),
      _buildTravelPlanPage(),
      _buildProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('旅遊應用')),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '主頁'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '行程規劃'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '個人設定'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
      ),
    );
  }
}
