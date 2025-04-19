import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class TravelFormPage extends StatefulWidget {
  final int dayIndex;
  final bool browseOnly;
  final Map<String, dynamic>? initialData;

  const TravelFormPage({
    super.key,
    required this.dayIndex,
    this.browseOnly = false,
    this.initialData,
  });

  @override
  State<TravelFormPage> createState() => _TravelFormPageState();
}

class _TravelFormPageState extends State<TravelFormPage> {
  List<Map<String, dynamic>> allSpots = [];
  List<Map<String, dynamic>> filteredSpots = [];
  List<Map<String, dynamic>> selectedSpots = [];

  String? selectedCity;
  String? selectedTown;
  String searchKeyword = '';
  Map<String, List<String>> cityTownMap = {};

  GoogleMapController? _mapController;
  final LatLng _center = const LatLng(23.6978, 120.9605); // 台灣中心點

  @override
  void initState() {
    super.initState();
    _loadSpotData();
    _loadCountyData();
  }

  Future<void> _loadSpotData() async {
    final raw = await rootBundle.loadString('assets/data/景點.csv');
    final lines = const LineSplitter().convert(raw);
    final headers = lines.first.split(',');
    allSpots = lines
        .skip(1)
        .map((line) => Map.fromIterables(headers, line.split(',')))
        .toList();
    setState(() {
      filteredSpots = allSpots;
    });
  }

  Future<void> _loadCountyData() async {
    final raw = await rootBundle.loadString('assets/data/country.csv');
    final rows = const LineSplitter().convert(raw);
    final header = rows.first.split(',');
    final map = <String, List<String>>{};

    for (final row in rows.skip(1)) {
      final values = row.split(',');
      final data = Map.fromIterables(header, values);
      final city = data['縣市']!.replaceAll('台', '臺');
      final town = data['鄉鎮市']!.replaceAll('台', '臺');
      map.putIfAbsent(city, () => []).add(town);
    }

    setState(() {
      cityTownMap = map;
    });
  }

  void _filterSpots() {
    setState(() {
      filteredSpots = allSpots.where((spot) {
        final cityMatch = selectedCity == null || spot['Region'] == selectedCity;
        final townMatch = selectedTown == null || spot['Town'] == selectedTown;
        final keywordMatch = searchKeyword.isEmpty ||
            (spot['Name'] ?? '').contains(searchKeyword);
        return cityMatch && townMatch && keywordMatch;
      }).toList();
    });
  }

  void _onSelectSpot(Map<String, dynamic> spot) {
    if (!selectedSpots.contains(spot)) {
      setState(() {
        selectedSpots.add(spot);
      });
    }
  }

  void _onSave() {
    Navigator.pop(context, {
      'success': true,
      'dayIndex': widget.dayIndex,
      'updatedSpots': selectedSpots,
      'transports': List.generate(selectedSpots.length - 1, (_) => '步行'),
    });
  }

  /// ✅ 平台判斷：手機顯示地圖，桌機顯示提示
  Widget _buildMapOrMessage() {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return SizedBox(
        height: 200,
        child: GoogleMap(
          onMapCreated: (controller) => _mapController = controller,
          initialCameraPosition: CameraPosition(target: _center, zoom: 7),
          markers: selectedSpots
              .map((spot) => Marker(
                    markerId: MarkerId(spot['Name']),
                    position: LatLng(
                      double.tryParse(spot['Latitude'] ?? '') ?? _center.latitude,
                      double.tryParse(spot['Longitude'] ?? '') ?? _center.longitude,
                    ),
                    infoWindow: InfoWindow(title: spot['Name']),
                  ))
              .toSet(),
        ),
      );
    } else {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '⚠️ 地圖功能僅支援 Android / iOS 手機平台',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇景點'),
      ),
      body: Column(
        children: [
          _buildMapOrMessage(),

          // 縣市 + 地區
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedCity,
                    hint: const Text("選擇縣市"),
                    items: cityTownMap.keys
                        .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCity = value;
                        selectedTown = null;
                        _filterSpots();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedTown,
                    hint: const Text("選擇地區"),
                    items: (cityTownMap[selectedCity] ?? [])
                        .map((town) => DropdownMenuItem(value: town, child: Text(town)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedTown = value;
                        _filterSpots();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // 搜尋欄
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '輸入關鍵字搜尋',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                searchKeyword = value;
                _filterSpots();
              },
            ),
          ),

          // 景點清單
          Expanded(
            child: ListView.builder(
              itemCount: filteredSpots.length,
              itemBuilder: (_, index) {
                final spot = filteredSpots[index];
                return ListTile(
                  title: Text(spot['Name'] ?? ''),
                  subtitle: Text("${spot['Region'] ?? ''} ${spot['Town'] ?? ''}"),
                  onTap: () => _onSelectSpot(spot),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.browseOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _onSave,
              icon: const Icon(Icons.check),
              label: const Text("完成選擇"),
            ),
    );
  }
}
