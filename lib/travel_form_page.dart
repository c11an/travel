import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/travel_info_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:travel/travel_schedule_page.dart';

class TravelFormPage extends StatefulWidget {
  final int dayIndex;
  final bool browseOnly;
  final Map<String, dynamic>? initialData;

  const TravelFormPage({
    super.key,
    this.dayIndex = 0,
    this.browseOnly = false,
    this.initialData,
  });

  @override
  State<TravelFormPage> createState() => _TravelFormPageState();
}

class _TravelFormPageState extends State<TravelFormPage> {
  List<Map<String, String>> allSpots = [];
  List<Map<String, String>> filteredSpots = [];
  List<Map<String, String>> selectedSpots = [];
  List<Map<String, String>> favoriteSpots = [];

  Map<String, List<String>> cityTownMap = {};
  String? selectedCity;
  String? selectedTown;

  LatLng? currentLocation;

  @override
  void initState() {
    super.initState();
    _loadSpots();
    _loadCountryData();
    _getUserLocation();
    _loadFavorites();
  }

  Future<void> _getUserLocation() async {
    Location location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final locData = await location.getLocation();
    setState(() {
      currentLocation = LatLng(
        locData.latitude ?? 25.0330,
        locData.longitude ?? 121.5654,
      );
    });
  }

  Future<void> _loadSpots() async {
    final rawData = await rootBundle.loadString('assets/data/ScenicSpot.csv');
    final csvRows = const CsvToListConverter().convert(rawData);
    final headers = csvRows.first.map((e) => e.toString()).toList();
    final data =
        csvRows.skip(1).map((row) {
          return Map<String, String>.fromIterables(
            headers,
            row.map((e) => e.toString()),
          );
        }).toList();

    setState(() {
      allSpots = data;
    });
  }

  Future<void> _loadCountryData() async {
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
      "苗栗縣", "臺中市", "彰化縣", "南投縣", "雲林縣", "嘉義市", "嘉義縣",
      "臺南市", "高雄市", "屏東縣", "宜蘭縣", "花蓮縣", "臺東縣",
      "澎湖縣", "金門縣", "連江縣"
    ];

    // 鄉鎮排序並在最前加入「不限」
    result.forEach((city, towns) {
      towns.sort();
      towns.insert(0, '不限');
    });

    // 依照自訂順序排序城市
    final Map<String, List<String>> sortedResult = {};
    for (var city in taiwanCityOrder) {
      if (result.containsKey(city)) {
        sortedResult[city] = result[city]!;
      }
    }

    setState(() {
      cityTownMap = sortedResult;
    });
  }


  void _filterByCityTown() {
    if (selectedCity != null && selectedTown != null) {
      setState(() {
        filteredSpots = allSpots.where((spot) {
          final regionMatch = spot['Region'] == selectedCity;
          final townMatch = selectedTown == '不限' || spot['Town'] == selectedTown;
          return regionMatch && townMatch;
        }).toList();
      });
    }
  }


  void _filterByKeyword(String keyword) {
    final kw = keyword.toLowerCase();
    setState(() {
      filteredSpots =
          allSpots.where((spot) {
            final combined =
                [
                  spot['Name'],
                  spot['Add'],
                  spot['Region'],
                  spot['Town'],
                ].join(' ').toLowerCase();
            return combined.contains(kw);
          }).toList();
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorite_spots') ?? [];
    setState(() {
      favoriteSpots =
          favList.map((e) => Map<String, String>.from(jsonDecode(e))).toList();
    });
  }

  Future<void> _toggleFavorite(Map<String, String> spot) async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorite_spots') ?? [];
    final name = spot['Name'] ?? '';

    final isFavorited = favList.any((e) => jsonDecode(e)['Name'] == name);

    if (isFavorited) {
      favList.removeWhere((e) => jsonDecode(e)['Name'] == name);
    } else {
      favList.add(jsonEncode(spot));
    }

    await prefs.setStringList('favorite_spots', favList);
    _loadFavorites();
  }

  bool _isFavorited(Map<String, String> spot) {
    return favoriteSpots.any((s) => s['Name'] == spot['Name']);
  }

  void _showSpotDialog(Map<String, String> spot) {
    final alreadyAdded = selectedSpots.any((s) => s['Name'] == spot['Name']);
    final alreadyFavorited = _isFavorited(spot);

    String imageUrl = '';
    try {
      final pictureJson = spot['Picture1'];
      if (pictureJson != null && pictureJson.isNotEmpty) {
        final parsed = json.decode(pictureJson);
        imageUrl = parsed['src'] ?? '';
      }
    } catch (_) {
      imageUrl = '';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(spot['Name'] ?? '無名稱'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((spot['Add'] ?? '').isNotEmpty)
                Text("📍 ${spot['Add']}")
              else
                const Text("📍 無地址"),
              const SizedBox(height: 8),
              if (imageUrl.startsWith('http'))
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                const Text("❌ 無圖片"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("關閉"),
            ),
            TextButton(
              onPressed: () {
                final lat = spot['Py'];
                final lng = spot['Px'];
                if (lat != null && lng != null) {
                  final url =
                      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              child: const Text('🧭 導航'),
            ),
            TextButton(
              onPressed: () {
                _toggleFavorite(spot);
                Navigator.pop(context);
              },
              child: Text(alreadyFavorited ? '⭐ 移除收藏' : '⭐ 加入收藏'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (alreadyAdded) {
                    selectedSpots.removeWhere((s) => s['Name'] == spot['Name']);
                  } else {
                    selectedSpots.add(spot);
                  }
                });
                Navigator.pop(context);
              },
              child: Text(alreadyAdded ? '❌ 移除行程' : '✅ 加入行程'),
            ),
          ],
        );
      },
    );
  }

  void _goToSchedulePage() async {
    if (widget.browseOnly) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目前是瀏覽模式，無法排入行程表')));
      return;
    }

    if (selectedSpots.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先選擇景點')));
      return;
    }

    Map<String, dynamic>? tripInfo = widget.initialData;

    if (tripInfo == null) {
      // ⛳ 如果沒有 initialData，跳到 TravelInfoInputPage 請使用者填資料
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const TravelInfoInputPage()),
      );

      if (result == null) {
        // 使用者取消或沒填資料
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未完成行程資訊填寫')));
        return;
      }
      tripInfo = result;
    }

    // 🛫 正常跳到 TravelSchedulePage 排行程
    final startStr = tripInfo['start_date'];
    final endStr = tripInfo['end_date'];

    if (startStr == null || endStr == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('行程資料異常，無法排表')));
      return;
    }

    final startDate = DateFormat('yyyy-MM-dd').parse(startStr);
    final endDate = DateFormat('yyyy-MM-dd').parse(endStr);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => TravelSchedulePage(
              selectedSpots: selectedSpots,
              startDate: startDate,
              endDate: endDate,
              selectedDayIndex: 0,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = filteredSpots.map((spot) {
      final lat = double.tryParse(spot['Py'] ?? '');
      final lng = double.tryParse(spot['Px'] ?? '');
      if (lat == null || lng == null) return null;

      return Marker(
        markerId: MarkerId(spot['Name'] ?? '無名'),
        position: LatLng(lat, lng),
        onTap: () => _showSpotDialog(spot),
        infoWindow: InfoWindow(
          title: spot['Name'],
          snippet: spot['Add'] ?? '',
        ),
      );
    }).whereType<Marker>().toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('探索地圖')),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text("選擇縣市"),
                      value: selectedCity,
                      items: cityTownMap.keys.map((city) {
                        return DropdownMenuItem(
                          value: city,
                          child: Text(city),
                        );
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text("選擇鄉鎮市區"),
                      value: selectedTown,
                      items: selectedCity == null
                          ? []
                          : cityTownMap[selectedCity]!.map((town) {
                              return DropdownMenuItem(
                                value: town,
                                child: Text(town),
                              );
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
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '輸入關鍵字搜尋景點',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _filterByKeyword,
              ),
            ),
            const SizedBox(height: 8),

            // ✅ 顯示地圖與景點列表或 fallback 訊息
            Expanded(
              child: filteredSpots.isNotEmpty
                  ? Column(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height / 3,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: currentLocation ?? const LatLng(25.0330, 121.5654),
                              zoom: 11,
                            ),
                            markers: markers,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            zoomControlsEnabled: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredSpots.length,
                            itemBuilder: (context, index) {
                              final spot = filteredSpots[index];
                              return ListTile(
                                title: Text(spot['Name'] ?? ''),
                                subtitle: Text(spot['Add'] ?? ''),
                                onTap: () => _showSpotDialog(spot),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  : const Center(child: Text("尚未選擇地區或沒有符合的景點")),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: selectedSpots.isNotEmpty
            ? () {
                Navigator.pop(context, {
                  'selectedSpots': selectedSpots,
                  'dayIndex': widget.dayIndex,
                });
              }
            : null,
        icon: const Icon(Icons.check),
        label: Text('完成 (${selectedSpots.length})'),
      ),
    );
  }

}
