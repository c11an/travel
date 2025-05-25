import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/ai_recommend_page.dart';
import 'package:travel/journal_page.dart';
import 'package:travel/profile_page.dart';
import 'package:travel/travel_day_page.dart';
import 'package:travel/travel_form_page.dart';
import 'package:travel/travel_input_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

//-----抓取近期活動資料-----//
Future<List<Map<String, String>>> fetchRecentEvents() async {
  final fallbackEvents = [
    {'title': '陽明山花季', 'date': '2025/05/01 ~ 2025/05/10', 'location': '陽明山公園'},
    {'title': '台南美食節', 'date': '2025/06/12 ~ 2025/06/16', 'location': '台南安平'},
    {'title': '澎湖海上煙火節', 'date': '2025/07/01 ~ 2025/07/05', 'location': '澎湖觀音亭'},
    {'title': '花蓮夏戀嘉年華', 'date': '2025/07/15 ~ 2025/07/20', 'location': '花蓮東大門夜市廣場'},
    {'title': '高雄駁二藝術展', 'date': '2025/08/05 ~ 2025/08/30', 'location': '高雄駁二藝術特區'},
    {'title': '台中爵士音樂節', 'date': '2025/10/10 ~ 2025/10/20', 'location': '台中市民廣場'},
    {'title': '南投火車市集', 'date': '2025/09/01 ~ 2025/09/03', 'location': '集集車站前廣場'},
    {'title': '新北淡水燈會', 'date': '2025/02/10 ~ 2025/02/20', 'location': '新北市淡水老街'},
    {'title': '宜蘭國際童玩節', 'date': '2025/07/01 ~ 2025/08/15', 'location': '宜蘭冬山河親水公園'},
    {'title': '金門風獅爺文化節', 'date': '2025/11/01 ~ 2025/11/05', 'location': '金門文化園區'},
  ];

  try {
    final url = Uri.parse('https://memory.culture.tw/api/Activity?category=6');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer 你的API金鑰', // <-- 改成你拿到的 API 金鑰
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      final events = data.map<Map<String, String>>((item) {
        final showInfo = item['showInfo'];
        String location = '未知地點';
        if (showInfo != null && showInfo is List && showInfo.isNotEmpty) {
          location = showInfo[0]['location'] ?? '未知地點';
        }

        return {
          'title': item['title'] ?? '',
          'date': "${item['startDate']} ~ ${item['endDate']}",
          'location': location,
        };
      }).toList();

      if (events.isEmpty) {
        print('📭 API 回傳空資料，使用預設活動');
        return fallbackEvents;
      }

      return events;
    } else {
      print('⚠️ API 回傳狀態錯誤：${response.statusCode}');
      return fallbackEvents;
    }
  } catch (e) {
    print('❌ API 發生錯誤：$e，使用預設活動資料');
    return fallbackEvents;
  }
}

//-----抓取近期活動資料-----//

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class RecentEventSection extends StatefulWidget {
  const RecentEventSection({super.key});

  @override
  State<RecentEventSection> createState() => _RecentEventSectionState();
}

class _RecentEventSectionState extends State<RecentEventSection> {
  late Future<List<Map<String, String>>> _futureEvents;

  @override
  void initState() {
    super.initState();
    _futureEvents = fetchRecentEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📅 近期活動',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, String>>>(
              future: _futureEvents,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return const Text('無法載入活動資料');
                } else {
                  final events = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.event),
                          title: Text(event['title'] ?? ''),
                          subtitle: Text(
                            "${event['date']}\n地點：${event['location']}",
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // 點進活動詳情頁的功能可以寫這裡
                          },
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
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
  List<Map<String, dynamic>> _savedTrips = [];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
    _loadCityTownData();
    _loadTripsFromStorage();
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
      "基隆市",
      "臺北市",
      "新北市",
      "桃園市",
      "新竹市",
      "新竹縣",
      "苗栗縣",
      "臺中市",
      "彰化縣",
      "南投縣",
      "雲林縣",
      "嘉義市",
      "嘉義縣",
      "臺南市",
      "高雄市",
      "屏東縣",
      "宜蘭縣",
      "花蓮縣",
      "臺東縣",
      "澎湖縣",
      "金門縣",
      "連江縣",
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

  Future<void> _loadSavedTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final tripListString = prefs.getStringList('trip_list') ?? [];
    setState(() {
      _savedTrips = tripListString
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();
    });
  }

  Future<void> _loadTripsFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final tripListString = prefs.getStringList('trip_list') ?? [];
    setState(() {
      _savedTrips = tripListString
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toSet() // 避免重複
          .toList();
    });
  }




  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // 在切換回首頁時重新載入行程
    if (index == 0) {
      _loadTripsFromStorage();
    }
  }


  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw '無法打開網址: $url';
    }
  }

  Widget _buildFeatureButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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

  //-------------主頁界面------------//
  Widget _buildHomePage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            const Text(
              "Trip Tok",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),

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
                    const Text(
                      '🗂 我的旅遊行程！',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_savedTrips.isEmpty)
                      const Text('目前沒有旅遊規劃紀錄', style: TextStyle(color: Colors.grey)),
                    ..._savedTrips.reversed.take(3).map((trip) => ListTile(
                        title: Text(trip['trip_name'] ?? '未命名行程'),
                        subtitle: Text("📅 ${trip['start_date']} ~ ${trip['end_date']}"),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
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
                                        .map<Map<String, String>>((s) => Map<String, String>.from(s))
                                        .toList())
                                    .toList(),
                                initialTransports: (trip['daily_transports'] as List)
                                    .map<List<String>>((list) => List<String>.from(list))
                                    .toList(),
                                readOnly: true,
                              ),
                            ),
                          ).then((_) {
                            _loadTripsFromStorage(); // 回到首頁後即時更新行程
                          });
                        },
                      )),

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

            // 功能按鈕
            Row(
              children: [
                _buildFeatureButton("交通", Icons.directions_car, () {
                  _launchURL("https://www.easyrent.com.tw/");
                }),
                const SizedBox(width: 20), // 這裡調整間距
                _buildFeatureButton("住宿", Icons.hotel, () {
                  _launchURL("https://www.agoda.com/zh-tw");
                }),
              ],
            ),
            const SizedBox(height: 20), // ✅ 上下間距（兩排按鈕之間）
            Row(
              children: [
                _buildFeatureButton("火車", Icons.train, () {
                  _launchURL("https://www.railway.gov.tw/tra-tip-web/tip/tip001/tip122/tripOne/byTrainNo");
                }),
                const SizedBox(width: 20), // 這裡調整間距
                _buildFeatureButton("高鐵", Icons.directions_railway, () {
                  _launchURL("https://www.thsrc.com.tw/ArticleContent/dea241a9-fe69-4e9d-b9a5-6caed6e486d6");
                }),
              ],
            ),

            const SizedBox(height: 20),

            // 🔥 推薦行程
            Align(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AIRecommendPage(),
                    ),
                  );
                },
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
                      Text(
                        '🔥 AI推薦行程',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text('點我開始推薦行程吧！', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

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
                  const Text(
                    '📊 榜單查詢',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  // 地點選單
                  ElevatedButton(
                    onPressed: () => _showLocationDialog(context),
                    child: Text(
                      "地點：${selectedCity ?? "未選擇"} ${selectedTown ?? ""}",
                    ),
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
            const SizedBox(height: 20),

            // 📅 近期活動（使用文化部開放資料 API）
            Align(
              alignment: Alignment.center,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📅 近期活動',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ✅ FutureBuilder 顯示活動資料
                    FutureBuilder<List<Map<String, String>>>(
                      future: fetchRecentEvents(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (snapshot.hasError) {
                          return const Text('無法載入活動資料');
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Text('目前沒有任何活動');
                        } else {
                          final events = snapshot.data!;
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: events.length,
                            itemBuilder: (context, index) {
                              final event = events[index];
                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: const Icon(Icons.event),
                                  title: Text(event['title'] ?? ''),
                                  subtitle: Text(
                                    "${event['date']}\n地點：${event['location']}",
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    // TODO: 加入詳情功能（可跳頁）
                                  },
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  //----------------//
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
                    items:
                        cityTownMap.keys.map((city) {
                          return DropdownMenuItem(
                            value: city,
                            child: Text(city),
                          );
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
                      items:
                          (cityTownMap[tempCity] ?? []).map((town) {
                            return DropdownMenuItem(
                              value: town,
                              child: Text(town),
                            );
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
      builder:
          (_) => SimpleDialog(
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
  Widget _buildExplorePage() =>
      const TravelFormPage(dayIndex: 0, browseOnly: true);

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomePage(),
      _buildExplorePage(),
      _buildTravelPlanPage(),
      _buildJournalPage(),
      _buildProfilePage(),
    ];

    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return false;
        } else {
          return true;
        }
      },
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: pages[_selectedIndex],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: '首頁'),
            const BottomNavigationBarItem(icon: Icon(Icons.explore), label: '探索'),
            const BottomNavigationBarItem(icon: Icon(Icons.map), label: '行程'),
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/images/journey.jpg',
                width: 70,
                height: 70,
                fit: BoxFit.contain,
              ),
              label: '日誌',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: '個人'),
          ],
        ),

      ),
    );

  }


}
