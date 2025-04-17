import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'travel_form_page.dart';

class TravelDayPage extends StatefulWidget {
  final String tripName;
  final DateTime startDate;
  final DateTime endDate;
  final int budget;
  final String transport;
  final List<List<Map<String, String>>>? initialSpots;       // 加入
  final List<List<String>>? initialTransports;               // 加入

  const TravelDayPage({
    super.key,
    required this.tripName,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.transport,
    this.initialSpots,
    this.initialTransports,
  });

  @override
  State<TravelDayPage> createState() => _TravelDayPageState();
}

class _TravelDayPageState extends State<TravelDayPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late int dayCount;
  late List<List<Map<String, String>>> dailySpots;
  late List<List<String>> dailyTransports;

  @override
  void initState() {
    super.initState();
    dayCount = widget.endDate.difference(widget.startDate).inDays + 1;
    _tabController = TabController(length: dayCount, vsync: this);

    dailySpots = widget.initialSpots ?? List.generate(dayCount, (_) => []);
    dailyTransports = widget.initialTransports ?? List.generate(dayCount, (_) => []);
  }

  void _addSpot(int dayIndex) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelFormPage(
          initialData: {'spots': dailySpots[dayIndex]},
          dayIndex: dayIndex,
        ),
      ),
    );

    if (result != null &&
        result is Map<String, dynamic> &&
        result['success'] == true &&
        result['dayIndex'] != null) {
      final int returnedDayIndex = result['dayIndex'];
      final updatedSpots = List<Map<String, String>>.from(result['updatedSpots'] ?? []);
      final transports = List<String>.from(result['transports'] ?? []);

      setState(() {
        dailySpots[returnedDayIndex] = updatedSpots;
        dailyTransports[returnedDayIndex] = transports;
      });
    }
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

    Navigator.pop(context, tripData); // ✅ 回傳資料給 TravelInputPage
  }

  void _showSpotDetail(Map<String, String> spot) {
    final name = spot['Name'] ?? '無名稱';
    final address = spot['Add'] ?? '無地址';
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: dayCount,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("🗓 安排每日行程"),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: List.generate(
              dayCount,
              (i) => Tab(
                text: DateFormat('MM/dd').format(widget.startDate.add(Duration(days: i))),
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: List.generate(dayCount, (dayIndex) {
            final spots = dailySpots[dayIndex];
            final transports = dailyTransports[dayIndex];
            final int itemCount = spots.length > 1 ? (spots.length * 2 - 1) : spots.length;
            return Column(
              children: [
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _addSpot(dayIndex),
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text("新增景點"),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: itemCount,
                    itemBuilder: (_, index) {
                      if (index.isEven) {
                        final spot = spots[index ~/ 2];
                        return ListTile(
                          onTap: () => _showSpotDetail(spot),
                          title: Text(spot['Name'] ?? '無名稱'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${spot['Region'] ?? ''} ${spot['Town'] ?? ''}'),
                              if ((spot['Add'] ?? '').isNotEmpty)
                                Text('📍 ${spot['Add']}'),
                            ],
                          ),
                        );
                      } else {
                        final transportIndex = (index - 1) ~/ 2;
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              transports.length > transportIndex ? transports[transportIndex] : '',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            );
          }),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _saveTrip,
            icon: const Icon(Icons.check),
            label: const Text("儲存行程"),
          ),
        ),
      ),
    );
  }
}
