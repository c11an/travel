import 'package:flutter/material.dart';
import 'dart:math';

class TravelSchedulePage extends StatefulWidget {
  final List<Map<String, String>> selectedSpots;
  final DateTime startDate;
  final DateTime endDate;
  final int selectedDayIndex; // 👈 多加這個，代表選哪一天！

  const TravelSchedulePage({
    super.key,
    required this.selectedSpots,
    required this.startDate,
    required this.endDate,
    required this.selectedDayIndex,
  });

  @override
  State<TravelSchedulePage> createState() => _TravelSchedulePageState();
}

class _TravelSchedulePageState extends State<TravelSchedulePage>
    with SingleTickerProviderStateMixin {
  late int tripDays;
  late Map<int, List<Map<String, String>>> dailySpots;
  late Map<int, List<String>> dailyTransports;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    tripDays = widget.endDate.difference(widget.startDate).inDays + 1;
    dailySpots = {for (int i = 0; i < tripDays; i++) i: []};

    // ✅ 這裡改！直接塞到指定 day
    if (widget.selectedSpots.isNotEmpty) {
      dailySpots[widget.selectedDayIndex]?.addAll(widget.selectedSpots);
    }

    _generateTransports();
    _tabController = TabController(length: tripDays, vsync: this);
  }

  void _generateTransports() {
    dailyTransports = {for (int i = 0; i < tripDays; i++) i: []};

    for (var entry in dailySpots.entries) {
      final spots = entry.value;
      for (int i = 0; i < spots.length - 1; i++) {
        final from = spots[i];
        final to = spots[i + 1];
        final distance = _calculateDistance(
          double.tryParse(from['Py'] ?? '') ?? 0,
          double.tryParse(from['Px'] ?? '') ?? 0,
          double.tryParse(to['Py'] ?? '') ?? 0,
          double.tryParse(to['Px'] ?? '') ?? 0,
        );
        if (distance < 1) {
          dailyTransports[entry.key]?.add(
            '🚶‍ 步行 ${distance.toStringAsFixed(1)}公里',
          );
        } else if (distance < 10) {
          dailyTransports[entry.key]?.add(
            '🛵 機車/汽車 ${distance.toStringAsFixed(1)}公里',
          );
        } else {
          dailyTransports[entry.key]?.add(
            '🚗 汽車/大眾運輸 ${distance.toStringAsFixed(1)}公里',
          );
        }
      }
    }
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
    final dailySpotsList = List.generate(tripDays, (i) => dailySpots[i] ?? []);
    final dailyTransportsList = List.generate(
      tripDays,
      (i) => dailyTransports[i] ?? [],
    );

    Navigator.pop(context, {
      'daily_spots': dailySpotsList,
      'daily_transports': dailyTransportsList,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('安排每日行程'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: List.generate(tripDays, (i) => Tab(text: 'Day ${i + 1}')),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(tripDays, (dayIndex) {
          final spots = dailySpots[dayIndex] ?? [];

          return spots.isEmpty
              ? const Center(child: Text('今日尚未安排景點'))
              : ReorderableListView(
                padding: const EdgeInsets.all(8),
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final spot = spots.removeAt(oldIndex);
                    spots.insert(newIndex, spot);
                    _generateTransports();
                  });
                },
                children: List.generate(spots.length, (index) {
                  final spot = spots[index];
                  return Card(
                    key: ValueKey(spot['Name'] ?? '$index'),
                    margin: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 12,
                    ),
                    child: ListTile(
                      title: Text(spot['Name'] ?? '無名稱'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${spot['Region'] ?? ''} ${spot['Town'] ?? ''}'),
                          if (index < (dailyTransports[dayIndex]?.length ?? 0))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                dailyTransports[dayIndex]![index],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                    ),
                  );
                }),
              );
        }),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: _saveSchedule,
          icon: const Icon(Icons.save),
          label: const Text("儲存行程"),
        ),
      ),
    );
  }
}
