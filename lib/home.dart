import 'package:flutter/material.dart';
import 'package:travel/journal_page.dart';
import 'package:travel/profile_page.dart';
import 'package:travel/travel_form_page.dart';
import 'package:travel/travel_input_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:csv/csv.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _currentPage = 0;
  final PageController _pageController = PageController();

  final List<String> _images = [
    'assets/images/jiufen.jpg',
    'assets/images/SunSet.jpg',
    'assets/images/Alishan.jpg',
  ];

  // 榜單用的選單狀態
  String? selectedCity;
  String? selectedTown;
  String? selectedCategory;

  Map<String, List<String>> cityTownMap = {};

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
    _loadCityTownData();
  }

  void _startAutoSlide() {
    Future.delayed(const Duration(seconds: 4), () {
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

  Future<void> _loadCityTownData() async {
    final raw = await rootBundle.loadString('assets/data/country.csv');
    final rows = const CsvToListConverter().convert(raw);
    final headers = rows.first.map((e) => e.toString()).toList();
    final data = rows.skip(1).map((row) {
      return Map<String, String>.fromIterables(
        headers,
        row.map((e) => e.toString()),
      );
    });

    final Map<String, List<String>> result = {};
    for (var row in data) {
      final city = row['縣市']?.replaceAll('台', '臺') ?? '';
      final town = row['鄉鎮市']?.replaceAll('台', '臺') ?? '';

      if (city.isEmpty || town.isEmpty) continue;

      result.putIfAbsent(city, () => []);
      if (!result[city]!.contains(town)) {
        result[city]!.add(town);
      }
    }

    // ✅ 台灣縣市的自訂順序
    final List<String> taiwanCityOrder = [
      "基隆市", "臺北市", "新北市", "桃園市", "新竹市", "新竹縣",
      "苗栗縣", "臺中市", "彰化縣", "南投縣",
      "雲林縣", "嘉義市", "嘉義縣", "臺南市", "高雄市", "屏東縣",
      "宜蘭縣", "花蓮縣", "臺東縣",
      "澎湖縣", "金門縣", "連江縣"
    ];

    // 鄉鎮排序
    result.forEach((city, towns) {
      towns.sort();
      towns.insert(0, ""); // 加入空白地區表示所有地區
    });

    // 依照自訂順序排序城市
    final Map<String, List<String>> sortedResult = {};
    for (var city in taiwanCityOrder) {
      if (result.containsKey(city)) {
        sortedResult[city] = result[city]!;
      }
    }

    setState(() {
      // 插入「所有」選項在最前
      final Map<String, List<String>> finalMap = {"所有": []};
      finalMap.addAll(sortedResult); // 加入原本排序好的縣市資料
      cityTownMap = finalMap;
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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw '無法打開網址: $url';
    }
  }

  Widget _buildFeatureButton(String label, IconData icon, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 輪播圖
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
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

            const Text("Trip Tok", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            // 功能按鈕
            Row(
              children: [
                _buildFeatureButton("交通", Icons.directions_car, () {
                  _launchURL("https://www.easyrent.com.tw/");
                }),
                _buildFeatureButton("住宿", Icons.hotel, () {
                  _launchURL("https://www.agoda.com/zh-tw");
                }),
              ],
            ),
            Row(
              children: [
                _buildFeatureButton("機票", Icons.flight, () {
                  _launchURL("https://flights.google.com/");
                }),
                _buildFeatureButton("旅遊網卡", Icons.sim_card, () {
                  _launchURL("https://yoyogoshop.com/");
                }),
              ],
            ),

            const SizedBox(height: 30),

            // 🗂 我的旅遊規劃
            Align(
              alignment: Alignment.center,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🗂 開始我的旅遊行程！',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text('目前沒有旅遊規劃紀錄', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _onItemTapped(2),
                      child: const Text('開始安排'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔥 推薦行程
            Align(
              alignment: Alignment.center,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0B2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('🔥 推薦行程',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text('目前沒有推薦內容，敬請期待', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 📊 榜單功能：地點、類別選單
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📊 榜單查詢', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  // 地點選單
                  ElevatedButton(
                    onPressed: () => _showLocationDialog(context),
                    child: Text("地點：${selectedCity ?? "未選擇"} ${selectedTown ?? ""}"),
                  ),
                  const SizedBox(height: 10),
                  // 類別選單
                  ElevatedButton(
                    onPressed: () => _showCategoryDialog(context),
                    child: Text("類別：${selectedCategory ?? "未選擇"}"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationDialog(BuildContext context) {
    String? tempCity = selectedCity;
    String? tempTown = selectedTown;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text("選擇地點"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("選擇縣市"),
                    value: tempCity,
                    items: cityTownMap.keys.map((city) {
                      return DropdownMenuItem(value: city, child: Text(city));
                    }).toList(),
                    onChanged: (val) {
                      setInnerState(() {
                        tempCity = val;
                        tempTown = null;
                      });
                    },
                  ),
                  if (tempCity != "所有")
                    DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text("選擇地區"),
                      value: tempTown,
                      items: (cityTownMap[tempCity] ?? []).map((town) {
                        return DropdownMenuItem(value: town, child: Text(town));
                      }).toList(),
                      onChanged: (val) {
                        setInnerState(() {
                          tempTown = val;
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("取消"),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedCity = tempCity;
                      selectedTown = tempTown;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("確認"),
                ),
              ],
            );
          },
        );
      },
    );
  }



  void _showCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text("選擇類別"),
        children: [
          ListTile(
            title: const Text("不限"),
            onTap: () => _selectCategory("不限"),
          ),
          ListTile(
            title: const Text("景點"),
            onTap: () => _selectCategory("景點"),
          ),
          ListTile(
            title: const Text("美食"),
            onTap: () => _selectCategory("美食"),
          ),
          ListTile(
            title: const Text("住宿"),
            onTap: () => _selectCategory("住宿"),
          ),
        ],
      ),
    );
  }


  void _selectCategory(String category) {
    setState(() {
      selectedCategory = category;
    });
    Navigator.pop(context);
  }

  Widget _buildTravelPlanPage() => const TravelInputPage();
  Widget _buildProfilePage() => const ProfilePage();
  Widget _buildJournalPage() => const JournalPage();
  Widget _buildExplorePage() => const TravelFormPage(dayIndex: 0, browseOnly: true);

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
