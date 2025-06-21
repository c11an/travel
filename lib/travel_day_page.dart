import 'dart:math';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/travel_note_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'travel_form_page.dart';
import 'map_view_page.dart'; // ⭐️ 要新增的地圖顯示頁面


class TravelDayPage extends StatefulWidget {
  final String tripName;
  final DateTime startDate;
  final DateTime endDate;
  final int budget;
  final String transport;
  final String? mood;
  final String? need;

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
    this.mood,
    this.need,
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
  //static const double hourBlockHeight = 100.0;
  static const hourBlockHeight = 100.0;
  static const distanceBlockHeight = 30.0;
  static const blockHeight = hourBlockHeight + distanceBlockHeight;



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

    if (dailySpots.length < dayCount) {
      dailySpots += List.generate(dayCount - dailySpots.length, (_) => []);
    }

    final incomingTransports = widget.initialTransports ?? [];
    dailyTransports = List.generate(
      dayCount,
      (index) => index < incomingTransports.length ? incomingTransports[index] : [],
    );

    // ✅ 這樣才會在資料載入後計算正確的交通方式與刷新畫面
    _loadNotesFromStorage().then((_) {
      _generateTransports();
      setState(() {});
    });
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

            // ⭐ 初始化時間從 08:00 開始
            int currentTime = 8;

            for (int i = 0; i < selectedSpots.length; i++) {
              final s = selectedSpots[i];
              final name = s['Name'] ?? '無名';
              final durationStr = s['Duration'] ?? '1';
              final duration = int.tryParse(durationStr) ?? 1;

              // 檢查時間與停留時間格式
              if (duration <= 0 || currentTime > 20) {
                debugPrint("❌ 景點 '$name' 資料錯誤或時間超出範圍");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❗ 景點 "$name" 時間格式錯誤或超過顯示範圍')),
                );
                continue;
              }

              // 找下一個可用時間（避免重疊）
              while (dailySpots[returnedDayIndex].any((s) =>
                  int.tryParse(s['Time'] ?? '0') == currentTime)) {
                currentTime++;
              }

              final timeStr = currentTime.toString().padLeft(2, '0');

              validSpots.add({
                'Name': name,
                'Add': s['Add'] ?? '',
                'Px': s['Px'] ?? '0',
                'Py': s['Py'] ?? '0',
                'Description': s['Description'] ?? '',
                'Time': timeStr,
                'Duration': duration.toString(),
              });

              // 🔁 將下一個景點的開始時間往後遞增
              currentTime += duration;
            }

            if (validSpots.isEmpty) {
              debugPrint("⚠️ 所有景點皆無法加入，請檢查格式");
              return;
            }

            // ✅ 補足 dailySpots 長度
            while (dailySpots.length <= returnedDayIndex) {
              dailySpots.add([]);
            }

            dailySpots[returnedDayIndex].addAll(validSpots);
            // 加入這段排序：
            // dailySpots[returnedDayIndex].sort((a, b) =>
            //     (int.tryParse(a['Time'] ?? '0') ?? 0)
            //         .compareTo(int.tryParse(b['Time'] ?? '0') ?? 0));
            debugPrint("📌 加入景點成功：${dailySpots[returnedDayIndex]}");

            _generateTransports();
            _saveNotesToStorage();
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
    List<String> tripList = prefs.getStringList('trip_list') ?? [];

    // ✅ 移除舊的同名行程（避免重複儲存）
    tripList.removeWhere((tripStr) {
      final decoded = jsonDecode(tripStr);
      return decoded['trip_name'] == widget.tripName;
    });

    // ✅ 加入新的行程
    tripList.add(jsonEncode(tripData));
    await prefs.setStringList('trip_list', tripList);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 行程已儲存')),
      );

      // ⭐️ 儲存完成後跳回 TravelInputPage
    Navigator.pop(context, tripData);
    
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
    print("🧠 mood: ${widget.mood}, 🎯 need: ${widget.need}");
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

                print("🌀 當前 Tab：Day ${dayIndex + 1}");
                print("📦 dailySpots.length = ${dailySpots.length}");
                print("📦 spots = $spots");
                print("🧭 Day $dayIndex 的 spots 數量為 ${spots.length}");


                if (spots.isEmpty) {
                  print("⚠️ 當日無景點！");
                } else {
                  for (var spot in spots) {
                    print("👀 顯示景點：${spot['Name']}，開始時間：${spot['Time']}，停留時間：${spot['Duration']} 小時");
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          print("🧩 LayoutBuilder 收到 spots: $spots");

                          final maxEndTime = spots.map((spot) {
                            final start = int.tryParse(spot['Time'] ?? '0') ?? 0;
                            final duration = int.tryParse(spot['Duration'] ?? '1') ?? 1;
                            return start + duration;
                          }).fold<int>(0, (prev, end) => end > prev ? end : prev);

                          final totalHeight = (maxEndTime * blockHeight + blockHeight).clamp(600.0, blockHeight * 24);


                          return SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: blockHeight * 24),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ⏰ 時間欄
                                  Column(
                                    children: List.generate(24, (i) {
                                      final hour = i.toString().padLeft(2, '0');
                                      return SizedBox(
                                        height: blockHeight,
                                        width: 80,
                                        child: Center(
                                          child: Text('$hour:00'),
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(width: 12),

                                  // 🗺️ 景點與距離圖層
                                  SizedBox(
                                    width: max(constraints.maxWidth - 92, 200),
                                    height: blockHeight * 24,
                                    child: Stack(
                                      children: [
                                        // 背景格與距離提示
                                        ...List.generate(24, (i) {
                                          final transports = dayIndex < dailyTransports.length
                                              ? dailyTransports[dayIndex]
                                              : [];
                                          final currentIndex = dailySpots[dayIndex].indexWhere(
                                              (s) => int.tryParse(s['Time'] ?? '') == i);
                                          final hasTransport = currentIndex != -1 && currentIndex < transports.length;

                                          return Stack(
                                            children: [
                                              // 🔲 景點主格線區塊
                                              Positioned(
                                                top: i * blockHeight,
                                                left: 0,
                                                right: 0,
                                                height: hourBlockHeight,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      top: BorderSide(color: Colors.grey.shade300),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // 🚗 移動距離提示
                                              Positioned(
                                                top: i * blockHeight + hourBlockHeight,
                                                left: 0,
                                                right: 0,
                                                height: distanceBlockHeight,
                                                child: hasTransport
                                                    ? Center(
                                                        child: Text(
                                                          transports[currentIndex],
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                            color: transports[currentIndex].contains('步行')
                                                                ? Colors.green
                                                                : transports[currentIndex].contains('機車')
                                                                    ? Colors.orange
                                                                    : Colors.blue,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      )
                                                    : const SizedBox.shrink(),
                                              ),
                                            ],
                                          );
                                        }),

                                        // 📥 拖曳目標區
                                        _buildDropTargets(dayIndex),

                                        // 📦 景點方塊與距離提示插入邏輯
                                        ..._buildSpotAndTransportBlocks(
                                          List<Map<String, String>>.from(spots),
                                          dayIndex,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );



                        },
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
      ? null
      : Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveTrip,
              icon: const Icon(Icons.save),
              label: const Text("儲存行程"),
              style: ElevatedButton.styleFrom(
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),


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

    debugPrint("📦 嘗試從 SharedPreferences 載入 notes_$tripName");

    if (storedNotes != null) {
      try {
        final decodedNotes = (jsonDecode(storedNotes) as List)
            .map<List<Map<String, String>>>((day) =>
                (day as List).map<Map<String, String>>((spot) =>
                    Map<String, String>.from(spot as Map)).toList()).toList();

        setState(() {
          dailySpots = decodedNotes;

          if (dailySpots.length < dayCount) {
            dailySpots += List.generate(dayCount - dailySpots.length, (_) => []);
          }
        });
      } catch (e) {
        debugPrint("❌ notes_$tripName 載入失敗：$e");
        setState(() {
          dailySpots = List.generate(dayCount, (_) => []);
        });
      }

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

    // if (storedNotes != null) {
      

    // }
  }

  Widget _buildSpotBlock(Map<String, String> spot, int dayIndex, {bool isFeedback = false}) {
    if (!spot.containsKey('Name')) {
      print("🚨 無效景點：$spot");
      return const SizedBox();
    }

    final duration = int.tryParse(spot['Duration'] ?? '1') ?? 1;
    final name = spot['Name'] ?? '無名稱';
    final time = spot['Time'] ?? '08';

    print("👀 顯示景點：$name，開始時間：$time，停留時間：$duration 小時");

    final container = Container(
      // ✅ 不設 width，讓外層決定（避免 feedback 出錯）
      height: duration * hourBlockHeight,
      decoration: BoxDecoration(
        color: isFeedback ? Colors.blue.withOpacity(0.6) : const Color.fromARGB(255, 128, 189, 239),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ 重點：讓內容自動壓縮
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: widget.readOnly ? null : () => _editDurationDialog(spot),
                icon: const Icon(Icons.access_time, color: Colors.white, size: 18),
                tooltip: '更改停留時間',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Flexible( // ✅ 這一層確保不超出方塊高度
            child: Text(
              '$duration 小時',
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),

    );

    if (isFeedback) {
      // ✅ 加上固定寬度（拖曳才會有實體尺寸）
      return SizedBox(
        width: MediaQuery.of(context).size.width - 100, // 可調整寬度
        child: container,
      );
    }

    return Dismissible(
      key: ValueKey(name + time),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        if (!widget.readOnly) {
          setState(() {
            dailySpots[dayIndex].remove(spot);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🗑️ 已刪除 $name')),
          );
        }
      },

      child: GestureDetector(
        onTap: () => _showSpotInfoDialog(spot),
        child: container,
      ),
    );
  }


  // 顯示簡化版景點資訊 Dialog（只有關閉與資訊按鈕）
  void _showSpotInfoDialog(Map<String, String> spot) {
    final name = spot['Name'] ?? '無名稱';
    final address = spot['Add'] ?? '無地址';
    String imageUrl = '';

    // 嘗試解析圖片 URL
    try {
      final pictureField = spot['Picture1'];
      if (pictureField != null && pictureField.isNotEmpty) {
        if (pictureField.trim().startsWith('{')) {
          final parsed = json.decode(pictureField);
          imageUrl = parsed['src'] ?? '';
        } else if (pictureField.startsWith('http')) {
          imageUrl = pictureField;
        }
      }
    } catch (e) {
      debugPrint("⚠️ 圖片解析錯誤：$e");
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(name),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300), // 👈 避免 overflow
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("📍 $address", style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  )
                else
                  const Text("❌ 無圖片"),
              ],
            ),
          ),
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
              final description = spot['Toldescribe'] ?? spot['Description'] ?? '❌ 沒有描述資料';
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("📘 景點資訊"),
                  content: SingleChildScrollView(
                    child: Text(description),
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
                  _generateTransports();
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

  Widget _buildDropTargets(int dayIndex) {
    return Positioned.fill(
      child: Builder(
        builder: (innerContext) {
          return DragTarget<Map<String, String>>(
            onWillAcceptWithDetails: (_) => !widget.readOnly,
            onAcceptWithDetails: (DragTargetDetails<Map<String, String>> details) {
              final RenderBox box = innerContext.findRenderObject() as RenderBox;
              final localOffset = box.globalToLocal(details.offset);
              final estimatedHour = (localOffset.dy / blockHeight).clamp(0, 23).floor();


              setState(() {
                final spot = details.data;

                /// ✅ 改成比對時間 + 名稱（更穩定）
                dailySpots[dayIndex].removeWhere((s) =>
                    s['Name'] == spot['Name'] && s['Time'] == spot['Time']);

                spot['Time'] = estimatedHour.toString();
                dailySpots[dayIndex].add(spot);

                // ✅ 排序景點（根據時間）
                dailySpots[dayIndex].sort((a, b) =>
                    (int.tryParse(a['Time'] ?? '0') ?? 0)
                        .compareTo(int.tryParse(b['Time'] ?? '0') ?? 0));

                _generateTransports();
                _saveNotesToStorage();
              });
            },
            builder: (context, candidateData, rejectedData) {
              return Container(
                color: candidateData.isNotEmpty
                    ? Colors.blue.withOpacity(0.05)
                    : Colors.transparent,
              );
            },
          );
        },
      ),
    );
  }

    List<Widget> _buildSpotAndTransportBlocks(
      List<Map<String, String>> spots,
      int dayIndex,
    ) {
      final widgets = <Widget>[];

      for (int i = 0; i < spots.length; i++) {
        final spot = spots[i];
        final startHour = int.tryParse(spot['Time'] ?? '8') ?? 8;
        final duration = int.tryParse(spot['Duration'] ?? '1') ?? 1;

        final spotHeight = duration * hourBlockHeight;
        final showTransport = i < dailyTransports[dayIndex].length;
        final transportHeight = showTransport ? distanceBlockHeight : 0;

        final top = startHour * blockHeight;
        final totalHeight = spotHeight + transportHeight;

        widgets.add(
          Positioned(
            top: top,
            left: 0,
            right: 0,
            height: totalHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ 景點方塊（唯讀不顯示拖曳）
                SizedBox(
                  height: spotHeight,
                  child: widget.readOnly
                      ? GestureDetector(
                          onTap: () => _showSpotInfoDialog(spot),
                          child: _buildSpotBlock(spot, dayIndex),
                        )
                      : Draggable<Map<String, String>>(
                          data: spot,
                          feedback: Material(
                            color: Colors.transparent,
                            child: _buildSpotBlock(spot, dayIndex, isFeedback: true),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: _buildSpotBlock(spot, dayIndex),
                          ),
                          child: GestureDetector(
                            onTap: () => _showSpotInfoDialog(spot),
                            child: _buildSpotBlock(spot, dayIndex),
                          ),
                        ),
                ),

                // ✅ 交通距離提示
                if (showTransport)
                  Container(
                    height: distanceBlockHeight,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Text(
                      dailyTransports[dayIndex][i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: dailyTransports[dayIndex][i].contains('步行')
                            ? Colors.green
                            : dailyTransports[dayIndex][i].contains('機車')
                                ? Colors.orange
                                : Colors.blue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      return widgets;
    }











}
