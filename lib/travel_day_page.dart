import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/travel_note_page.dart';
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

    // ✅ 確保 dailySpots 長度足夠
    if (dailySpots.length < dayCount) {
      dailySpots += List.generate(dayCount - dailySpots.length, (_) => []);
    }

    final incomingTransports = widget.initialTransports ?? [];
    dailyTransports = List.generate(
      dayCount,
      (index) =>
          index < incomingTransports.length ? incomingTransports[index] : [],
    );

    _generateTransports();
    _loadNotesFromStorage(); // ✅ 載入儲存的心得
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
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TravelFormPage(browseOnly: false, dayIndex: dayIndex),
        ),
      );

      if (result != null && result is Map) {
        final List<Map<String, String>> selectedSpots =
            List<Map<String, String>>.from(result['selectedSpots'] ?? []);
        final int returnedDayIndex = dayIndex;

        debugPrint("✅ 選擇景點回傳：$selectedSpots");

        if (selectedSpots.isNotEmpty) {
          setState(() {
            final List<Map<String, String>> validSpots = [];

            for (int i = 0; i < selectedSpots.length; i++) {
              final s = selectedSpots[i];
              final name = s['Name'] ?? '無名';
              final duration = s['Duration'] ?? '1';

              // ⭐ 自動分配時間：從 08 開始依序往後排
              final time = (8 + i).toString().padLeft(2, '0');

              if (int.tryParse(time) == null || int.tryParse(duration) == null) {
                debugPrint("❌ 景點 '$name' 欄位格式錯誤 (Time: $time, Duration: $duration)");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❗ 景點 "$name" 時間格式錯誤')),
                );
                continue;
              }

              validSpots.add({
                'Name': name,
                'Add': s['Add'] ?? '',
                'Px': s['Px'] ?? '0',
                'Py': s['Py'] ?? '0',
                'Description': s['Description'] ?? '',
                'Time': time,
                'Duration': duration,
              });
            }

            if (validSpots.isEmpty) {
              debugPrint("⚠️ 所有景點皆無法加入，請檢查格式");
              return;
            }

            dailySpots[returnedDayIndex].addAll(validSpots);
            debugPrint("📌 加入景點成功：${dailySpots[returnedDayIndex]}");

            _generateTransports();
            _saveNotesToStorage(); // 可選：確保儲存
          });
        } else {
          debugPrint("⚠️ selectedSpots 為空");
        }
      } else {
        debugPrint("⚠️ result 為 null 或格式錯誤: $result");
      }
    } catch (e, stack) {
      debugPrint("❗ 發生錯誤：$e");
      debugPrint("🔍 堆疊追蹤：$stack");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❗ 發生錯誤，請稍後再試')),
      );
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

  void _saveTrip() async {
    final tripData = {
      'trip_name': widget.tripName,
      'start_date': DateFormat('yyyy-MM-dd').format(widget.startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(widget.endDate),
      'budget': widget.budget,
      'transport': widget.transport,
      'daily_spots': dailySpots,
      'daily_transports': dailyTransports,
    };

    final prefs = await SharedPreferences.getInstance();
    final tripList = prefs.getStringList('trip_list') ?? [];
    tripList.add(jsonEncode(tripData));
    await prefs.setStringList('trip_list', tripList);

    if (mounted) {
      //Navigator.pop(context, tripData); // 返回並傳回行程資料
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 行程已儲存')),
);

    }
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

  int _currentDayIndex = 0; // ✅ 新增：用來追蹤目前選擇的日期

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
          onTap: (index) {
            setState(() {
              _currentDayIndex = index;
            });
          },
          tabs: List.generate(dayCount, (i) => Tab(text: 'Day ${i + 1}')),
        ),
        actions: [
          if (widget.readOnly)
            IconButton(
              onPressed: () => _showNotes(viewOnly: true, dayIndex: _currentDayIndex),
              icon: const Icon(Icons.notes),
              tooltip: "查看心得",
            ),
        ],
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
                final spots = dayIndex < dailySpots.length ? dailySpots[dayIndex] : [];

                print("🌀 當前 Tab：Day \${dayIndex + 1}");
                print("📦 dailySpots.length = \${dailySpots.length}");
                print("📦 spots = \${spots}");

                if (spots.isEmpty) {
                  print("⚠️ 當日無景點！");
                } else {
                  for (var spot in spots) {
                    print("👀 顯示景點：\${spot['Name']}，開始時間：\${spot['Time']}，停留時間：\${spot['Duration']} 小時");
                  }
                }

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
                          if (!widget.readOnly) const SizedBox(width: 12),
                          if (!widget.readOnly)
                            IconButton(
                              onPressed: _saveTrip,
                              icon: const Icon(Icons.save),
                              tooltip: "儲存行程",
                            ),
                          if (widget.readOnly)
                            IconButton(
                              onPressed: () => _showNotes(viewOnly: true, dayIndex: _currentDayIndex),
                              icon: const Icon(Icons.notes),
                              tooltip: "查看心得",
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: List.generate(13, (i) {
                                final hour = 8 + i;
                                return SizedBox(
                                  height: 60,
                                  width: 60,
                                  child: Center(
                                    child: Text("${hour.toString().padLeft(2, '0')}:00"),

                                  ),
                                );
                              }),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: MediaQuery.of(context).size.width - 100,
                              child: SizedBox(
                                height: 13 * 60,
                                child: Stack(
                                  children: [
                                    ...spots.asMap().entries.map((entry) {
                                      final spot = entry.value;
                                      final startHour = int.tryParse(spot['Time'] ?? '8') ?? 8;
                                      final duration = int.tryParse(spot['Duration'] ?? '1') ?? 1;

                                      return Positioned(
                                        top: (startHour - 8) * 60,
                                        left: 0,
                                        right: 0,
                                        height: duration * 60,
                                        child: Draggable<Map<String, String>>(
                                          data: spot,
                                          feedback: _buildSpotBlock(spot, dayIndex, isFeedback: true),
                                          childWhenDragging: Container(),
                                          child: GestureDetector(
                                            onTap: () => _editDurationDialog(spot),
                                            child: _buildSpotBlock(spot, dayIndex),
                                          ),
                                        ),
                                      );
                                    }),
                                    ..._buildDropTargets(dayIndex),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.readOnly
        ? Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: () => _showNotes(viewOnly: false, dayIndex: _currentDayIndex),
              icon: const Icon(Icons.note_add),
              label: const Text("新增心得"),
            ),
          )
        : null,
    );
  }



  /// 跳轉到撰寫或查看心得頁面
  void _showNotes({required bool viewOnly, required int dayIndex}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelNotePage(
          dailySpots: dailySpots[dayIndex],
          dayIndex: dayIndex,
          readOnly: viewOnly,
        ),
      ),
    ).then((updatedSpots) {
      if (updatedSpots != null) {
        setState(() {
          dailySpots[dayIndex] = updatedSpots;
          _saveNotesToStorage(); // ✅ 儲存心得
        });
      }
    });
  }

  // ✅ 新增儲存心得到 SharedPreferences
  Future<void> _saveNotesToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final tripName = widget.tripName;
    final encodedNotes = jsonEncode(dailySpots);
    await prefs.setString('notes_$tripName', encodedNotes);
  }

  // ✅ 載入儲存的心得
  Future<void> _loadNotesFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final tripName = widget.tripName;
    final storedNotes = prefs.getString('notes_$tripName');

    if (storedNotes != null) {
      final decodedNotes = List<List<Map<String, String>>>.from(
        jsonDecode(storedNotes).map(
          (day) => List<Map<String, String>>.from(
            day.map<Map<String, String>>((spot) => Map<String, String>.from(spot)),
          ),
        ),
      );

      setState(() {
      dailySpots = decodedNotes;
      if (dailySpots.length < dayCount) {
        dailySpots += List.generate(dayCount - dailySpots.length, (_) => []);
      }
    });

    }
  }

  Widget _buildSpotBlock(Map<String, String> spot, int dayIndex, {bool isFeedback = false}) {

    if (!spot.containsKey('Name')) {
        print("🚨 無效景點：$spot");
        return const SizedBox(); // or a red box
    }

    final duration = int.tryParse(spot['Duration'] ?? '1') ?? 1;
    final name = spot['Name'] ?? '無名稱';
    final time = spot['Time'] ?? '08';

    print("👀 顯示景點：$name，開始時間：$time，停留時間：${duration} 小時");

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isFeedback ? Colors.blue.withOpacity(0.6) : Colors.blue,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: FittedBox( // ✅ 防止溢位
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: () => _editDurationDialog(spot),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(60, 30), // ✅ 避免太大
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('$duration 小時', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }




  void _editDurationDialog(Map<String, String> spot) {
    final controller = TextEditingController(text: spot['Duration'] ?? '1');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("設定停留時間"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '停留時間（小時）'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                setState(() {
                  spot['Duration'] = value.toString();
                });
                Navigator.pop(context);
              } else {
                // 顯示錯誤訊息
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❗ 請輸入有效的整數（大於 0）')),
                );
              }
            },
            child: const Text("確認"),
          )
        ],
      ),
    );
  }

  List<Positioned> _buildDropTargets(int dayIndex) {
    return List.generate(13, (i) {
      final hour = 8 + i;
      return Positioned(
        top: i * 60,
        left: 0,
        right: 0,
        height: 60,
        child: DragTarget<Map<String, String>>(
          onWillAccept: (_) => true,
          onAccept: (spot) {
            setState(() {
              spot['Time'] = hour.toString();
            });
          },
          builder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100, // 拖曳格背景
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
      );
    });
  }
}
