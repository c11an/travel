import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ⛳ 請務必填入你自己的可用 API Key，且要啟用 Directions API
const String googleApiKey = 'YOUR_REAL_GOOGLE_API_KEY';

class MapViewPage extends StatefulWidget {
  final List<Map<String, String>> spots;

  const MapViewPage({super.key, required this.spots});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  late GoogleMapController mapController;
  final List<Marker> _markers = [];
  final Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _setupMap();
  }

  Future<void> _setupMap() async {
    final points = widget.spots
        .map((s) => LatLng(
              double.tryParse(s['Py'] ?? '') ?? 0,
              double.tryParse(s['Px'] ?? '') ?? 0,
            ))
        .where((p) => p.latitude != 0 && p.longitude != 0) // 過濾掉無效點
        .toList();

    if (points.isEmpty) return;

    // 加入標記
    for (int i = 0; i < points.length; i++) {
      _markers.add(
        Marker(
          markerId: MarkerId('spot_$i'),
          position: points[i],
          infoWindow: InfoWindow(title: widget.spots[i]['Name'] ?? ''),
        ),
      );
    }

    // 路線
    await _getRouteFromAPI(points);
    setState(() {});
  }

  Future<void> _getRouteFromAPI(List<LatLng> points) async {
    if (points.length < 2) return;

    final origin = '${points.first.latitude},${points.first.longitude}';
    final destination = '${points.last.latitude},${points.last.longitude}';

    String waypoints = '';
    if (points.length > 2) {
      final midPoints = points.sublist(1, points.length - 1);
      waypoints = '&waypoints=${midPoints.map((p) => '${p.latitude},${p.longitude}').join('|')}';
    }

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination$waypoints&mode=driving&key=$googleApiKey';

    final res = await http.get(Uri.parse(url));

    if (res.statusCode != 200) {
      print("❌ API 錯誤: ${res.statusCode}");
      print(res.body);
      return;
    }

    final data = jsonDecode(res.body);
    if (data['routes'].isNotEmpty) {
      final encoded = data['routes'][0]['overview_polyline']['points'];
      final decoded = PolylinePoints().decodePolyline(encoded);

      setState(() {
        _routePoints = decoded.map((e) => LatLng(e.latitude, e.longitude)).toList();
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route_${DateTime.now().millisecondsSinceEpoch}'),
            color: Colors.blue,
            width: 5,
            points: _routePoints,
          ),
        );
      });
    } else {
      print("⚠️ 沒有找到路線：${data['status']}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.spots.firstWhere(
      (s) =>
          double.tryParse(s['Py'] ?? '') != null &&
          double.tryParse(s['Px'] ?? '') != null,
      orElse: () => {'Py': '0', 'Px': '0'},
    );

    final center = LatLng(
      double.tryParse(first['Py'] ?? '') ?? 0,
      double.tryParse(first['Px'] ?? '') ?? 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('地圖查看行程')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: 13),
        markers: Set.from(_markers),
        polylines: _polylines,
        onMapCreated: (controller) => mapController = controller,
      ),
    );
  }
}
