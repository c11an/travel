import 'package:flutter/material.dart';
import 'dart:math';

class TravelSchedulePage extends StatefulWidget {
  final List<Map<String, String>> selectedSpots;
  final DateTime startDate;
  final DateTime endDate;

  const TravelSchedulePage({
    super.key,
    required this.selectedSpots,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<TravelSchedulePage> createState() => _TravelSchedulePageState();
}

class _TravelSchedulePageState extends State<TravelSchedulePage>
    with SingleTickerProviderStateMixin {
  late int tripDays;
  late Map<int, List<Map<String, String>>> dailySpots;
  late List<String> transports;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    tripDays = widget.endDate.difference(widget.startDate).inDays + 1;
    dailySpots = {for (int i = 0; i < tripDays; i++) i: []};
    if (widget.selectedSpots.isNotEmpty) {
      for (int i = 0; i < widget.selectedSpots.length; i++) {
        dailySpots[i % tripDays]?.add(widget.selectedSpots[i]);
      }
    }
    transports = _generateTransports();
    _tabController = TabController(length: tripDays, vsync: this);
  }

  List<String> _generateTransports() {
    List<String> results = [];
    final allSpots = dailySpots.values.expand((list) => list).toList();
    for (int i = 0; i < allSpots.length - 1; i++) {
      final from = allSpots[i];
      final to = allSpots[i + 1];
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
        transport =
            '🚗 汽車 / 🚌 公車 / 🚆 火車（約 ${distance.toStringAsFixed(1)} 公里）';
      }
      results.add(transport);
    }
    return results;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degreesToRadians(double deg) => deg * (pi / 180);

  void _saveSchedule() {
    final allSpots = dailySpots.values.expand((list) => list).toList();
    final tripData = {
      'trip_type':
          allSpots.isNotEmpty ? (allSpots.first['Class1'] ?? '自訂') : '自訂',
      'region':
          allSpots.isNotEmpty ? (allSpots.first['Region'] ?? '未指定') : '未指定',
      'spots': allSpots,
      'transports': transports,
    };
    Navigator.pop(context, {
      'success': true,
      'updatedSpots': allSpots,
      'tripData': tripData,
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tripDays,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('排行程'),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: List.generate(
              tripDays,
              (index) => Tab(text: 'Day ${index + 1}'),
            ),
          ),
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('📍 每日行程（可依天調整）'),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: List.generate(tripDays, (index) {
                  final spots = dailySpots[index]!;
                  return ReorderableListView(
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = spots.removeAt(oldIndex);
                        spots.insert(newIndex, item);
                      });
                    },
                    children: List.generate(spots.length, (i) {
                      final spot = spots[i];
                      return Card(
                        key: ValueKey(spot['Name'] ?? '$index-$i'),
                        child: ListTile(
                          title: Text(spot['Name'] ?? '無名稱'),
                          subtitle: Text(
                            '${spot['Region'] ?? ''} ${spot['Town'] ?? ''}',
                          ),
                          trailing: const Icon(Icons.drag_handle),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveSchedule,
                  icon: const Icon(Icons.save),
                  label: const Text('儲存行程'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
