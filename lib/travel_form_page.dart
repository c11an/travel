import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/travel_schedule_page.dart';
import 'dart:convert';

class TravelFormPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final bool returnToInputPage;
  final int dayIndex;
  final bool browseOnly;

  const TravelFormPage({
    super.key,
    this.initialData,
    this.returnToInputPage = false,
    this.dayIndex = 0,
    this.browseOnly = false,
  });

  @override
  State<TravelFormPage> createState() => _TravelFormPageState();
}

class _TravelFormPageState extends State<TravelFormPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _cityController = TextEditingController();
  List<Map<String, String>> allSpots = [];
  List<Map<String, String>> filteredSpots = [];
  List<Map<String, String>> selectedSpots = [];
  List<String> favoriteSpotNames = [];
  Map<String, List<Map<String, String>>> favoritesByCity = {};
  Map<String, List<String>> cityTownMap = {};
  String? selectedCity;
  String? selectedTown;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllCsvFiles();
    _loadFavorites();
    _loadCountyData();
    _cityController.addListener(() {
      _filterByKeyword(_cityController.text);
    });

    if (widget.initialData != null && widget.initialData!['spots'] != null) {
      selectedSpots = List<Map<String, String>>.from(widget.initialData!['spots']);
    }
  }

  Future<void> _loadAllCsvFiles() async {
    final raw = await rootBundle.load('assets/data/ScenicSpot.csv');
    final decoded = const Utf8Decoder().convert(raw.buffer.asUint8List());
    final rows = const CsvToListConverter().convert(decoded);

    final headers = rows.first.map((e) => e.toString()).toList();
    final data = rows.skip(1).map((row) {
      return Map<String, String>.fromIterables(
        headers,
        row.map((e) => e.toString()),
      );
    }).toList();

    setState(() {
      allSpots = data;
      filteredSpots = data;
    });
  }

  Future<void> _loadCountyData() async {
    final raw = await rootBundle.loadString('assets/data/country.csv');
    final rows = const CsvToListConverter().convert(raw);
    final headers = rows.first.map((e) => e.toString()).toList();
    final data = rows.skip(1).map((row) {
      return Map<String, String>.fromIterables(
        headers,
        row.map((e) => e.toString()),
      );
    }).toList();

    // 建立對應 map，並將「台」轉成「臺」
    Map<String, List<String>> map = {};
    for (var row in data) {
      final city = row['縣市']?.replaceAll('台', '臺') ?? '';
      final town = row['鄉鎮市']?.replaceAll('台', '臺') ?? '';
      map.putIfAbsent(city, () => []);
      if (!map[city]!.contains(town)) {
        map[city]!.add(town);
      }
    }

    // ✅ 自訂縣市排序
    final orderedCityList = [
      '基隆市', '臺北市', '新北市', '桃園市', '新竹市', '新竹縣',
      '苗栗縣', '臺中市', '彰化縣', '南投縣', '雲林縣', '嘉義市', '嘉義縣',
      '臺南市', '高雄市', '屏東縣', '宜蘭縣', '花蓮縣', '臺東縣',
      '澎湖縣', '金門縣', '連江縣'
    ];

    // 🔁 排序並建立新的 map（地區也排序過）
    final sortedMap = {
      for (var city in orderedCityList)
        if (map.containsKey(city)) city: (map[city]!..sort())
    };

    setState(() {
      cityTownMap = sortedMap;
    });
  }


  void _filterByCityTown() {
    if (selectedCity != null && selectedTown != null) {
      setState(() {
        filteredSpots = allSpots.where((spot) =>
            spot['Region'] == selectedCity &&
            spot['Town'] == selectedTown).toList();
      });
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorite_spots') ?? [];
    final favorites = favList.map((e) => Map<String, String>.from(jsonDecode(e))).toList();

    final names = favorites.map((e) => e['Name'] ?? '無名稱').toList();
    final Map<String, List<Map<String, String>>> grouped = {};
    for (var spot in favorites) {
      final city = spot['Region'] ?? '未分類';
      grouped.putIfAbsent(city, () => []).add(spot);
    }

    setState(() {
      favoriteSpotNames = List<String>.from(names);
      favoritesByCity = grouped;
    });
  }

  Future<void> _toggleFavorite(Map<String, String> spot) async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorite_spots') ?? [];

    final spotName = spot['Name'] ?? '無名稱';
    bool alreadyFavorited = favList.any((e) {
      final item = jsonDecode(e);
      return item['Name'] == spotName;
    });

    if (alreadyFavorited) {
      favList.removeWhere((e) {
        final item = jsonDecode(e);
        return item['Name'] == spotName;
      });
    } else {
      favList.add(jsonEncode(spot));
    }

    await prefs.setStringList('favorite_spots', favList);
    _loadFavorites();
  }

  void _filterByKeyword(String keyword) {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) {
      setState(() {
        filteredSpots = List.from(allSpots);
      });
      return;
    }

    final keywords = kw.split(' ');
    setState(() {
      filteredSpots = allSpots.where((spot) {
        final values = [
          spot['Region'] ?? '',
          spot['Town'] ?? '',
          spot['Name'] ?? '',
          spot['Description'] ?? '',
          spot['Add'] ?? '',
        ].join(' ').toLowerCase();
        return keywords.every((k) => values.contains(k));
      }).toList();
    });
  }

  void _addSpot(Map<String, String> spot) {
    if (!selectedSpots.any((s) => s['Name'] == spot['Name'])) {
      setState(() {
        selectedSpots.add(spot);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("景點已經加入行程囉！")),
      );
    }
  }


  void _removeSpot(int index) {
    setState(() {
      selectedSpots.removeAt(index);
    });
  }

  void _goToSchedulePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelSchedulePage(
          selectedSpots: selectedSpots,
          initialTripData: widget.initialData,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic> && result['success'] == true) {
      Navigator.pop(context, {
        'dayIndex': widget.dayIndex,
        'updatedSpots': List<Map<String, String>>.from(result['updatedSpots'] ?? []),
        'transports': List<String>.from(result['transports'] ?? []),
        'success': true,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.browseOnly ? '找景點與收藏' : '選擇 Day ${widget.dayIndex + 1} 景點'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("選擇縣市"),
                    value: selectedCity,
                    items: cityTownMap.keys.map((city) {
                      return DropdownMenuItem(value: city, child: Text(city));
                    }).toList(),
                    onChanged: (city) {
                      setState(() {
                        selectedCity = city;
                        selectedTown = null;
                        filteredSpots = [];
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("選擇地區"),
                    value: selectedTown,
                    items: selectedCity == null
                        ? []
                        : cityTownMap[selectedCity]!.map((town) {
                            return DropdownMenuItem(value: town, child: Text(town));
                          }).toList(),
                    onChanged: (town) {
                      setState(() {
                        selectedTown = town;
                        _filterByCityTown();
                      });
                    },
                  ),
                ),
              ],
            ),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: '輸入關鍵字搜尋景點',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: '所有景點'),
                      Tab(text: '我的收藏'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSpotList(filteredSpots),
                        _buildFavoritesGroupedByCity(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.browseOnly) ...[
              const Divider(),
              const Text('🧳 已選擇的行程：', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedSpots.length,
                  itemBuilder: (context, index) {
                    final spot = selectedSpots[index];
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(spot['Name'] ?? '無名稱'),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () => _removeSpot(index),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _goToSchedulePage,
                icon: const Icon(Icons.check),
                label: const Text('完成，下一步'),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSpotList(List<Map<String, String>> spots) {
    return ListView.builder(
      itemCount: spots.length,
      itemBuilder: (context, index) {
        final spot = spots[index];
        final name = spot['Name'] ?? '無名稱';
        final address = spot['Add'] ?? '';
        final isFavorite = favoriteSpotNames.contains(name);

        return Card(
          child: ListTile(
            onTap: () => _showSpotDetail(spot),
            title: Text(name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${spot['Region'] ?? ''} ${spot['Town'] ?? ''}'),
                if (address.isNotEmpty)
                  Text('📍 $address', style: const TextStyle(color: Colors.black54)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isFavorite ? Icons.star : Icons.star_border, color: Colors.amber),
                  onPressed: () => _toggleFavorite(spot),
                ),
                if (!widget.browseOnly)
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: () => _addSpot(spot),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesGroupedByCity() {
    if (favoritesByCity.isEmpty) {
      return const Center(child: Text('目前沒有收藏的景點'));
    }

    return ListView(
      children: favoritesByCity.entries.map((entry) {
        final city = entry.key;
        final spots = entry.value;
        return ExpansionTile(
          title: Text(city, style: const TextStyle(fontWeight: FontWeight.bold)),
          children: spots.map((spot) {
            selectedSpots.any((s) => s['Name'] == spot['Name']);
            return ListTile(
              title: Text(spot['Name'] ?? '無名稱'),
              subtitle: Text(spot['Add'] ?? '無地址'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _toggleFavorite(spot),
                  ),
                  if (!widget.browseOnly)
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () => _addSpot(spot),
                    ),
                ],
              ),
              onTap: () => _showSpotDetail(spot),
            );
          }).toList(),
        );
      }).toList(),
    );
  }


  void _showSpotDetail(Map<String, String> spot) {
    final name = spot['Name'] ?? '無名稱';
    final address = spot['Add'] ?? '';
    final desc = spot['Description'] ?? '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (desc.isNotEmpty) Text("📖 $desc"),
              if (address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("📍 地址：$address"),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("關閉"),
            )
          ],
        );
      },
    );
  }
}