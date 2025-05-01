import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'travel_form_page.dart';
import 'map_view_page.dart'; // ⭐️ 要新增的地圖顯示頁面

class TravelDayPage extends StatefulWidget {
  final String tripName;
  final DateTime startDate;
  final DateTime endDate;
  final int budget;
  final String transport;
  final List<List<Map<String, String>>>? initialSpots;
  final List<List<String>>? initialTransports;
  final bool readOnly;

  const TravelDayPage({
    super.key,
    required this.tripName,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.transport,
    this.initialSpots,
    this.initialTransports,
    this.readOnly = false,
  });

  @override
  State<TravelDayPage> createState() => _TravelDayPageState();
}

class _TravelDayPageState extends State<TravelDayPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late int dayCount;
  late List<List<Map<String, String>>> dailySpots;
  late List<List<String>> dailyTransports;

  @override
  void initState() {
    super.initState();
    dayCount = widget.endDate.difference(widget.startDate).inDays + 1;
    _tabController = TabController(length: dayCount, vsync: this);

    final incomingSpots = widget.initialSpots ?? [];
    dailySpots = List.generate(
      dayCount,
      (index) => index < incomingSpots.length ? incomingSpots[index] : [],
    );

    final incomingTransports = widget.initialTransports ?? [];
    dailyTransports = List.generate(
      dayCount,
      (index) =>
          index < incomingTransports.length ? incomingTransports[index] : [],
    );

    _generateTransports();
  }

  void _generateTransports() {
    dailyTransports = List.generate(dayCount, (_) => []);
    for (int day = 0; day < dayCount; day++) {
      final spots = dailySpots[day];
      final List<String> transports = [];
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
          transports.add('🚶‍ 步行 ${distance.toStringAsFixed(1)}公里');
        } else if (distance < 10) {
          transports.add('🚵 機車/汽車 ${distance.toStringAsFixed(1)}公里');
        } else {
          transports.add('🚗 汽車/大眾運輸 ${distance.toStringAsFixed(1)}公里');
        }
      }
      dailyTransports[day] = transports;
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

  double _degreesToRadians(double degree) => degree * (pi / 180);

  void _exploreAndAddSpots(int dayIndex) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelFormPage(browseOnly: false, dayIndex: dayIndex),
      ),
    );

    if (result != null && result is Map) {
      final List<Map<String, String>> selectedSpots =
          List<Map<String, String>>.from(result['selectedSpots'] ?? []);
      final int returnedDayIndex = result['dayIndex'] ?? dayIndex;

      if (selectedSpots.isNotEmpty) {
        setState(() {
          dailySpots[returnedDayIndex].addAll(selectedSpots);
          _generateTransports();
        });
      }
    }
  }

  void _showMap(int dayIndex) {
    final spots = dailySpots[dayIndex];
    if (spots.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapViewPage(spots: spots),
      ),
    );
  }

  void _saveTrip() {
    final tripData = {
      'trip_name': widget.tripName,
      'start_date': DateFormat('yyyy-MM-dd').format(widget.startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(widget.endDate),
      'budget': widget.budget,
      'transport': widget.transport,
      'daily_spots': dailySpots,
      'daily_transports': dailyTransports,
    };

    Navigator.pop(context, tripData);
  }

  void _showSpotDetail(Map<String, String> spot) {
    final name = spot['Name'] ?? '無名稱';
    final address = spot['Add'] ?? '無地址';
    final desc = spot['Description'] ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          ),
        ],
      ),
    );
  }

  void _showDeletedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑️ 景點已刪除')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripDuration =
        '${DateFormat('yyyy/MM/dd').format(widget.startDate)} ~ ${DateFormat('yyyy/MM/dd').format(widget.endDate)}';

    return Scaffold(
      appBar: AppBar(
        title: Text('🛢️ ${widget.tripName}'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: List.generate(dayCount, (i) => Tab(text: 'Day ${i + 1}')),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: Colors.blue.shade50,
            padding: const EdgeInsets.all(12),
            child: Text(
              '旅遊期間：$tripDuration',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(dayCount, (dayIndex) {
                final spots = dailySpots[dayIndex];

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          if (!widget.readOnly)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _exploreAndAddSpots(dayIndex),
                                icon: const Icon(Icons.add_location_alt),
                                label: const Text("探索新增景點"),
                              ),
                            ),
                          if (!widget.readOnly) const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showMap(dayIndex),
                              icon: const Icon(Icons.map),
                              label: const Text("在地圖查看"),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: spots.isEmpty
                          ? const Center(
                              child: Text(
                                '今日尚未安排景點',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ReorderableListView(
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
                                return Dismissible(
                                  key: ValueKey(spot['Name'] ?? '$index'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  confirmDismiss: (direction) async {
                                    return await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('刪除景點'),
                                        content: const Text('確定要刪除這個景點嗎？'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            child: const Text('取消'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(true),
                                            child: const Text('刪除'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  onDismissed: (_) {
                                    setState(() {
                                      spots.removeAt(index);
                                      _generateTransports();
                                    });
                                    _showDeletedMessage();
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: ListTile(
                                      title: Text(spot['Name'] ?? '無名稱'),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${spot['Region'] ?? ''} ${spot['Town'] ?? ''}'),
                                          if (index < (dailyTransports[dayIndex].length ?? 0))
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                dailyTransports[dayIndex][index],
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: ReorderableDragStartListener(
                                        index: index,
                                        child: const Icon(Icons.drag_handle),
                                      ),
                                      onTap: () => _showSpotDetail(spot),
                                    ),
                                  ),
                                );
                              }),
                    ),
                  )
                  ],
                );
              }),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.readOnly
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: _saveTrip,
                icon: const Icon(Icons.check),
                label: const Text("儲存行程"),
              ),
            ),
    );
  }
}
