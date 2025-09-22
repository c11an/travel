import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
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
  GoogleMapController? _mapController;
  BitmapDescriptor? defaultMarker;
  BitmapDescriptor? favoritedMarker;
  BitmapDescriptor? selectedMarker;

  bool isListExpanded = true;

  Marker? _activeMarker;


  String? selectedCategory = "景點"; // 預設選擇景點
  @override
  void initState() {
    super.initState();
    _loadSpots();
    _getUserLocation();
    _loadFavorites();
    _loadCustomMarkers();
  }

  Future<void> _loadCustomMarkers() async {
    defaultMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    favoritedMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    selectedMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
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
    try {
      final fileName = selectedCategory == "景點" ? 'ScenicSpot_tag.csv' : 'Restaurant.csv';
      final rawData = await rootBundle.loadString('assets/data/$fileName');

      // ✅ 使用 compute 處理 CSV 並去除 BOM
      final data = await compute(_parseCsvDataWithBomFix, rawData);

      setState(() {
        allSpots = data;
        filteredSpots = data;
      });

      await _loadCountryData(); // ✅ 確保 Spot 有了才載入縣市鄉鎮
    } catch (e) {
      print('❌ 載入錯誤: $e');
    }
  }

  List<Map<String, String>> parseCsvData(String rawData) {
    final rows = const CsvToListConverter().convert(rawData);
    final headers = rows.first.map((e) => e.toString()).toList();
    final data = rows.skip(1).map((row) {
      return Map<String, String>.fromIterables(
        headers,
        row.map((e) => e.toString()),
      );
    }).toList();
    return data;
  }

  Future<void> _loadCountryData() async {
    // 直接從 allSpots 載入 Region 和 Town
    final Map<String, List<String>> result = {};
    for (var spot in allSpots) {
      final city = spot['Region'] ?? '';
      final town = spot['Town'] ?? '';

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
      selectedCity = null; // ✅ 重置選擇
      selectedTown = null;
    });

    print("📍 cityTownMap loaded: ${cityTownMap.keys}");
  }

  void _filterByCityTown() {
    setState(() {
      filteredSpots = allSpots.where((spot) {
        final regionMatch = selectedCity == null || selectedCity == '不限' || spot['Region'] == selectedCity;
        final townMatch = selectedTown == null || selectedTown == '不限' || spot['Town'] == selectedTown;
        return regionMatch && townMatch;
      }).toList();
    });
  }

  void _filterByKeyword(String keyword) {
    final kw = keyword.toLowerCase();
    setState(() {
      filteredSpots = allSpots.where((spot) {
        final combined = [
          spot['Name'] ?? '',
          spot['Add'] ?? '',
          spot['Region'] ?? '',
          spot['Town'] ?? ''
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
      final pictureField = spot['Picture1'];
      print("🖼️ Picture1: $pictureField"); // Debug 用
      if (pictureField != null && pictureField.isNotEmpty) {
        if (pictureField.trim().startsWith('{')) {
          // 如果是 JSON 格式（舊版格式）
          final parsed = json.decode(pictureField);
          imageUrl = parsed['src'] ?? '';
        } else if (pictureField.startsWith('http')) {
          // ✅ 你的格式會走到這裡
          imageUrl = pictureField;
        }
      }
    } catch (e) {
      print('⚠️ 圖片處理錯誤: $e');
      imageUrl = '';
    }

    showDialog(
      context: context,
      builder: (context) {
        final description = (spot['Description']?.trim().isNotEmpty ?? false)
            ? spot['Description']
            : (spot['Toldescribe'] ?? '❌ 沒有描述資料');

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
                  child: SizedBox(
                    height: 150,
                    width: MediaQuery.of(context).size.width * 0.8,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
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
            if (!widget.browseOnly)
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
            TextButton(
              onPressed: () {
                final description = (spot['Toldescribe']?.trim().isNotEmpty ?? false)
                    ? spot['Toldescribe']
                    : (spot['Description'] ?? '❌ 沒有描述資料');

                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("📘 景點資訊"),
                    content: SingleChildScrollView(
                      child: Text(description ?? '❌ 沒有描述資料'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("關閉"),
                      ),
                    ],
                  ),
                );
              },
              child: const Text("📘 資訊"),
            ),
          ],

        );
      },
    );

  }

  void _goToSchedulePage() async {
    if (widget.browseOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目前是瀏覽模式，無法排入行程表')),
      );
      return;
    }

    if (selectedSpots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先選擇景點')),
      );
      return;
    }

    // 1) 先把可為 null 的 initialData 兜成不為空的 Map
    final Map<String, dynamic> info = (widget.initialData ?? {});

    // 2) 安全取得日期（同時支援 start_date / startDate 等常見鍵名）
    final DateTime? startDate = _toDate(info['start_date'] ?? info['startDate'] ?? info['start']);
    final DateTime? endDate   = _toDate(info['end_date']   ?? info['endDate']   ?? info['end']);

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('行程日期缺失或格式錯誤，無法排表')),
      );
      return;
    }

    // 3) 正常跳到排程頁
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelSchedulePage(
          selectedSpots: selectedSpots,
          startDate: startDate,
          endDate: endDate,
          selectedDayIndex: 0,
        ),
      ),
    );
  }

  /// 安全把動態值轉成 DateTime
  /// - 支援：DateTime 物件、或字串（yyyy-MM-dd / yyyy/MM/dd / yyyyMMdd / ISO 8601）
  /// - 失敗回傳 null
  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;

      // 先嘗試 Dart 內建解析（可吃多數 ISO 格式）
      try { return DateTime.parse(s); } catch (_) {}

      // 再試常見格式
      for (final fmt in ['yyyy-MM-dd', 'yyyy/MM/dd', 'yyyyMMdd']) {
        try { return DateFormat(fmt).parseStrict(s); } catch (_) {}
      }
    }
    return null;
  }


  @override
Widget build(BuildContext context) {
  final markers = _activeMarker != null ? {_activeMarker!} : <Marker>{};


  return Scaffold(
    appBar: AppBar(title: const Text('探索地圖')),
    body: Stack(
      children: [
        /// 背景地圖
        GoogleMap(
          onMapCreated: (controller) => _mapController = controller,
          initialCameraPosition: CameraPosition(
            target: currentLocation ?? const LatLng(25.0330, 121.5654),
            zoom: 11,
          ),
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
        ),

        /// 上方搜尋/篩選區（半透明卡片）
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          items: const [
                            DropdownMenuItem(value: "景點", child: Text("景點")),
                            DropdownMenuItem(value: "美食", child: Text("美食")),
                          ],
                          onChanged: (category) {
                            setState(() {
                              selectedCategory = category;
                              _loadSpots();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
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
                            });
                            _filterByCityTown(); // 🔥 加上這行觸發篩選
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
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: '輸入關鍵字搜尋景點',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _filterByKeyword,
                  ),
                ],
              ),
            ),
          ),
        ),

        /// 下方展開/收合卡片列表（以按鈕控制）
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isListExpanded ? 250 : 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black26)],
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => isListExpanded = !isListExpanded),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      isListExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      size: 28,
                    ),
                  ),
                ),
                if (isListExpanded) buildLegend(),
                if (isListExpanded)
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredSpots.length,
                      itemBuilder: (context, index) {
                        final spot = filteredSpots[index];
                        return ListTile(
                          title: Text(spot['Name'] ?? ''),
                          subtitle: Text(spot['Add'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isFavorited(spot))
                                const Icon(Icons.star, color: Colors.amber),
                              if (selectedSpots.any((s) => s['Name'] == spot['Name']))
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.event_available, color: Colors.green),
                                ),
                            ],
                          ),
                          onTap: () {
                            final lat = double.tryParse(spot['Py'] ?? '');
                            final lng = double.tryParse(spot['Px'] ?? '');
                            if (_mapController != null && lat != null && lng != null) {
                              final target = LatLng(lat, lng);

                              // ✅ 更新 marker，只顯示這一筆
                              setState(() {
                                _activeMarker = Marker(
                                  markerId: MarkerId(spot['Name'] ?? '無名'),
                                  position: target,
                                  icon: defaultMarker ?? BitmapDescriptor.defaultMarker,
                                  onTap: () => _showSpotDialog(spot),
                                  infoWindow: InfoWindow(
                                    title: spot['Name'],
                                    snippet: spot['Add'] ?? '',
                                  ),
                                );
                              });

                              // ✅ 移動地圖到該 marker
                              _mapController!.animateCamera(
                                CameraUpdate.newLatLng(target),
                              );
                            }
                          },

                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
    floatingActionButton: widget.browseOnly
        ? null
        : FloatingActionButton.extended(
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




  Widget buildLegend() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        legendItem(Colors.green, '加入行程'),
        legendItem(Colors.yellow, '收藏'),
        legendItem(Colors.red, '一般景點'),
      ],
    ),
  );
}

Widget legendItem(Color color, String label) {
  return Row(
    children: [
      Icon(Icons.place, color: color),
      const SizedBox(width: 4),
      Text(label),
    ],
  );
}



}

List<Map<String, String>> _parseCsvDataWithBomFix(String rawCsv) {
    final csvList = const CsvToListConverter().convert(rawCsv, eol: '\n');

    // 處理欄位名稱去掉 \ufeff（BOM）
    final header = csvList[0]
        .map((e) => e.toString().replaceAll('\ufeff', '').trim())
        .toList();

    return csvList.sublist(1).map((row) {
      final map = <String, String>{};
      for (int i = 0; i < header.length; i++) {
        map[header[i]] = row[i].toString();
      }
      return map;
    }).toList();
  }
