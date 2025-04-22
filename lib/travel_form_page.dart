import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    _loadCountyData();
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

  Future<void> _loadCountyData() async {
    final raw = await rootBundle.loadString('assets/data/country.csv');
    final rows = const CsvToListConverter().convert(raw);
    final headers = rows.first.map((e) => e.toString()).toList();
    final data =
        rows.skip(1).map((row) {
          return Map<String, String>.fromIterables(
            headers,
            row.map((e) => e.toString()),
          );
        }).toList();

    Map<String, List<String>> map = {};
    for (var row in data) {
      final city = row['縣市']?.replaceAll('台', '臺') ?? '';
      final town = row['鄉鎮市']?.replaceAll('台', '臺') ?? '';
      map.putIfAbsent(city, () => []);
      if (!map[city]!.contains(town)) {
        map[city]!.add(town);
      }
    }

    map.forEach((key, value) => value.sort());

    setState(() {
      cityTownMap = map;
    });
  }

  void _filterByCityTown() {
    if (selectedCity != null && selectedTown != null) {
      setState(() {
        filteredSpots =
            allSpots
                .where(
                  (spot) =>
                      spot['Region'] == selectedCity &&
                      spot['Town'] == selectedTown,
                )
                .toList();
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

  void _goToSchedulePage() {
    if (selectedSpots.isEmpty || widget.initialData == null) {
      print('🚫 選擇的景點為空或沒有 initialData');
      return;
    }

    print('📦 initialData: ${widget.initialData}');

    final startStr = widget.initialData!['start_date'];
    final endStr = widget.initialData!['end_date'];

    if (startStr == null || endStr == null) {
      print('❗ start_date 或 end_date 為 null');
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
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers =
        filteredSpots
            .map((spot) {
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
            })
            .whereType<Marker>()
            .toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('探索地圖')),
      body: Column(
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
                    items:
                        cityTownMap.keys.map((city) {
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
                    items:
                        selectedCity == null
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
          if (filteredSpots.isNotEmpty)
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
          if (selectedSpots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedSpots.length,
                  itemBuilder: (context, index) {
                    final spot = selectedSpots[index];
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Text(spot['Name'] ?? '無名稱'),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedSpots.removeAt(index);
                              });
                            },
                            child: const Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          if (selectedSpots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ElevatedButton.icon(
                onPressed: _goToSchedulePage,
                icon: const Icon(Icons.calendar_today),
                label: const Text('排入行程表'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
