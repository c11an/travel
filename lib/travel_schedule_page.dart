import 'package:flutter/material.dart';
import 'dart:math';

class TravelSchedulePage extends StatefulWidget {
  final List<Map<String, String>> selectedSpots;
  final Map<String, dynamic>? initialTripData;

  const TravelSchedulePage({
    super.key,
    required this.selectedSpots,
    this.initialTripData,
  });

  @override
  State<TravelSchedulePage> createState() => _TravelSchedulePageState();
}

class _TravelSchedulePageState extends State<TravelSchedulePage> {
  late List<Map<String, String>> spots;
  late List<String> transports;

  @override
  void initState() {
    super.initState();
    spots = List.from(widget.selectedSpots);
    transports = _generateTransports(spots);
  }

  List<String> _generateTransports(List<Map<String, String>> spots) {
    List<String> results = [];
    for (int i = 0; i < spots.length - 1; i++) {
      final from = spots[i];
      final to = spots[i + 1];
      final lat1 = double.tryParse(from['Py'] ?? '');
      final lon1 = double.tryParse(from['Px'] ?? '');
      final lat2 = double.tryParse(to['Py'] ?? '');
      final lon2 = double.tryParse(to['Px'] ?? '');

      if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
        results.add('❓ 無法判斷');
        continue;
      }

      final distance = _calculateDistance(lat1, lon1, lat2, lon2);
      String transport;
      if (distance < 1) {
        transport = '🚶‍ 步行（約 ${distance.toStringAsFixed(1)} 公里）';
      } else if (distance < 10) {
        transport = '🛵 機車 / 🚗 汽車（約 ${distance.toStringAsFixed(1)} 公里）';
      } else {
        transport = '🚗 汽車 / 🚌 公車 / 🚆 火車（約 ${distance.toStringAsFixed(1)} 公里）';
      }

      results.add(transport);
    }
    return results;
  }

  void _saveSchedule() async {
    final tripData = {
      'trip_type': spots.isNotEmpty ? (spots.first['Class1'] ?? '自訂') : '自訂',
      'region': spots.isNotEmpty ? (spots.first['Region'] ?? '未指定') : '未指定',
      'spots': spots,
      'transports': transports,
    };

    Navigator.pop(context, {
      'success': true,
      'updatedSpots': spots,
      'tripData': tripData,
    });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degreesToRadians(double deg) => deg * (pi / 180);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('排行程'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('📍 拖曳安排景點順序：'),
              const SizedBox(height: 8),
              Expanded(
                child: ReorderableListView(
                  children: List.generate(
                    spots.isEmpty ? 0 : (spots.length * 2 - 1),
                    (i) {
                      if (i.isEven) {
                        final index = i ~/ 2;
                        final spot = spots[index];
                        return Card(
                          key: ValueKey(spot),
                          child: ListTile(
                            title: Text(spot['Name'] ?? '無名稱'),
                            subtitle: Text('${spot['Region'] ?? ''} ${spot['Town'] ?? ''}'),
                            trailing: const Icon(Icons.drag_handle),
                          ),
                        );
                      } else {
                        final index = (i - 1) ~/ 2;
                        return Center(
                          key: ValueKey('transport_$i'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              transports.length > index ? transports[index] : '',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex.isOdd || newIndex.isOdd) return;
                    setState(() {
                      final item = spots.removeAt(oldIndex ~/ 2);
                      if (newIndex ~/ 2 >= spots.length) {
                        spots.add(item);
                      } else {
                        spots.insert(newIndex ~/ 2, item);
                      }
                      transports = _generateTransports(spots);
                    });
                  },
                ),
              ),

              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _saveSchedule,
                icon: const Icon(Icons.save),
                label: const Text('儲存行程'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
