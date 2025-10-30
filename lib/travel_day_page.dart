import 'dart:math';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/home.dart';
import 'package:travel/travel_input_page.dart';
import 'package:travel/travel_note_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'travel_form_page.dart';
import 'map_view_page.dart'; // ⭐️ 要新增的地圖顯示頁面
import 'package:http/http.dart' as http; // 上傳後端需要
import 'package:flutter_dotenv/flutter_dotenv.dart';

final String backendBaseUrl =
    dotenv.env['BACKEND_BASE_URL'] ?? 'https://default-url.com';
final String userUid = dotenv.env['USER_UID'] ?? 'anonymous';


class TravelDayPage extends StatefulWidget {
  final String tripName;
  final DateTime startDate;
  final DateTime endDate;
  final int budget;
  final String transport;
  final String? mood;
  final String? need;

  final ScrollController _scrollController = ScrollController();
  final List<List<Map<String, String>>>? initialSpots;
  final List<List<String>>? initialTransports;
  final bool readOnly;
  final bool fromAiResult; // ← 新增：是否由 AI 推薦結果頁進來

  TravelDayPage({
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
    this.fromAiResult = false, // 預設 false，不影響其他入口
  });

  @override
  State<TravelDayPage> createState() => _TravelDayPageState();

}

// ===== 文青：奶茶米色系 =====
const kBgCream     = Color(0xFFFAF3E0); // 背景：淡奶茶米色
const kCardBase    = Color(0xFFEAD7B7); // 卡片/按鍵底：奶茶棕
const kPressedTint = Color(0xFFD6C2A1); // 按下/hover：更深一階
const kTextDark    = Color(0xFF4E342E); // 文字：深棕
const kAccent      = Color(0xFFB48A60); // 點綴：拿鐵咖啡色


class _TravelDayPageState extends State<TravelDayPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late int dayCount;
  late List<List<Map<String, String>>> dailySpots;
  late List<List<String>> dailyTransports;
  late List<ScrollController> _scrollControllers;
  //static const double hourBlockHeight = 100.0;
  static const hourBlockHeight = 100.0;
  static const distanceBlockHeight = 30.0;
  static const blockHeight = hourBlockHeight + distanceBlockHeight;
  //final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;


  @override
  void initState() {
    super.initState();

    dayCount = widget.endDate.difference(widget.startDate).inDays + 1;
    _tabController = TabController(length: dayCount, vsync: this);
    _scrollControllers = List.generate(dayCount, (_) => ScrollController());

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

    // ✅ 補上 GPT 景點沒有 Time/Duration 的處理
    for (int dayIndex = 0; dayIndex < dailySpots.length; dayIndex++) {
      for (var spot in dailySpots[dayIndex]) {
        if (!spot.containsKey('Time') && spot.containsKey('TimeSlot')) {
          final timeSlot = spot['TimeSlot']!;
          final parts = timeSlot.split('~');
          if (parts.length == 2) {
            final start = parts[0].trim();
            final end = parts[1].trim();

            final startHour = int.tryParse(start.split(':').first);
            final endHour = int.tryParse(end.split(':').first);

            if (startHour != null && endHour != null) {
              spot['Time'] = startHour.toString().padLeft(2, '0');
              spot['Duration'] = (endHour - startHour).toString();
            }
          }
        }

        if (!spot.containsKey('Time')) {
          final time = _extractTimeFromText(spot['Raw'] ?? '');
          if (time != null) spot['Time'] = time;
        }

        if (!spot.containsKey('Duration')) {
          spot['Duration'] = '1';
        }
      }
    }

    // ✅ 畫面 build 完才執行 scroll 跳轉，避免 not attached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in _scrollControllers) {
        if (controller.hasClients) {
          controller.jumpTo(800); // 一格 100px，高度為 8 * 100 = 800px
        }
      }
    });

    _loadNotesFromStorage().then((_) {
      _generateTransports();
      setState(() {});
    });

    // ✅ Debug log
    print("🧳 TravelDayPage 收到 initialSpots: ${widget.initialSpots?.length}");
    for (int i = 0; i < (widget.initialSpots?.length ?? 0); i++) {
      print("📆 Day ${i + 1} 景點數量: ${widget.initialSpots![i].length}");
      for (final spot in widget.initialSpots![i]) {
        print("  🔸 ${spot['Name']} (${spot['TimeSlot']})");
      }
    }
  }

  List<Map<String, String>> favoriteSpots = [];

  bool _isFavorited(Map<String, String> spot) {
    return favoriteSpots.any((s) => s['Name'] == spot['Name']);
  }

  void _toggleFavorite(Map<String, String> spot) {
    final exists = _isFavorited(spot);
    setState(() {
      if (exists) {
        favoriteSpots.removeWhere((s) => s['Name'] == spot['Name']);
      } else {
        favoriteSpots.add(spot);
      }
    });
  }



  @override
  void dispose() {
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }


  String? _extractTimeFromText(String text) {
    final match = RegExp(r'^(\d{1,2}):\d{2}').firstMatch(text);
    if (match != null) {
      final hour = int.tryParse(match.group(1) ?? '');
      if (hour != null) {
        return hour.toString().padLeft(2, '0');
      }
    }
    return null;
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

  // void _saveTrip() async {
  //   if (_isSaving) return;
  //   _isSaving = true;

  //   final tripData = {
  //     'trip_name': widget.tripName,
  //     'start_date': DateFormat('yyyy-MM-dd').format(widget.startDate),
  //     'end_date': DateFormat('yyyy-MM-dd').format(widget.endDate),
  //     'budget': widget.budget,
  //     'transport': widget.transport,
  //     'daily_spots': dailySpots,
  //     'daily_transports': dailyTransports,
  //   };

  //   final prefs = await SharedPreferences.getInstance();
  //   List<String> tripList = prefs.getStringList('trip_list') ?? [];

  //   tripList.removeWhere((tripStr) {
  //     final decoded = jsonDecode(tripStr);
  //     return decoded['trip_name'] == widget.tripName;
  //   });

  //   tripList.add(jsonEncode(tripData));
  //   await prefs.setStringList('trip_list', tripList);

  //   if (mounted) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('✅ 行程已儲存')),
  //     );
  //     Navigator.pop(context, tripData);
  //   }

  //   print("🔁 儲存觸發：${DateTime.now()}");

  //   _isSaving = false;
  // }

  // ✅ CHANGED：先本機儲存，再推到後端，並做防重複提交

  // ✅ NEW：呼叫後端 /sync_hfl_data，把行程推上去
  Future<void> _pushToBackend() async {
    final uri = Uri.parse('$backendBaseUrl/hfl/update');
    final payload = _buildUploadPayload();
    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint("❌ 後端錯誤: ${res.statusCode} ${res.body}");
      throw Exception('後端回應 ${res.statusCode}');
    }
  }


  Future<void> _saveTrip() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 1) 本機儲存（沿用你原本的 trip_list 機制）
      final tripData = {
        'trip_name': widget.tripName,
        'start_date': DateFormat('yyyy-MM-dd').format(widget.startDate),
        'end_date': DateFormat('yyyy-MM-dd').format(widget.endDate),
        'budget': widget.budget,
        'transport': widget.transport,
        'daily_spots': dailySpots,
        'daily_transports': dailyTransports,
        'mood': widget.mood,
        'need': widget.need,
      };

      final prefs = await SharedPreferences.getInstance();
      List<String> tripList = prefs.getStringList('trip_list') ?? [];

      // 移除同名舊行程，避免重覆
      tripList.removeWhere((tripStr) {
        final decoded = jsonDecode(tripStr);
        return decoded['trip_name'] == widget.tripName;
      });

      tripList.add(jsonEncode(tripData));
      await prefs.setStringList('trip_list', tripList);

      // 2) 推到後端（只有在使用者按「儲存」時才上傳）
      await _pushToBackend();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 行程已儲存並同步到後端')),
      );

      // 回傳給上一頁（若需要）
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TravelInputPage()),
      );

      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 儲存或同步失敗：${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

    // 若是從 AI 推薦結果頁進來，禁止系統返回（Android 實體返回鍵）
    return WillPopScope(
      onWillPop: () async => !widget.fromAiResult,
      child: Scaffold(
        backgroundColor: kBgCream, // ✅ 背景
        appBar: AppBar(
          title: Text('🛢️ ${widget.tripName}'),

          // fromAiResult 時把左上角返回鍵拿掉
          automaticallyImplyLeading: !widget.fromAiResult,

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

          // 右上角 Home（只在 fromAiResult 時出現）
          actions: [
            if (widget.fromAiResult)
              IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: '回首頁',
                onPressed: () {
                  // 回首頁並清空路由堆疊
                  // 如果你有命名路由（如 '/home' 或 '/'），可以改用 pushNamedAndRemoveUntil
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
                  );
                },
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
                style: const TextStyle(fontWeight: FontWeight.bold,color: kTextDark),
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
                                onPressed: () => _showNotesAllDays(viewOnly: true),
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
                              controller: _scrollControllers[dayIndex],
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
                                                      color: kCardBase.withOpacity(0.5), // ✅ 奶茶半透明底
                                                      border: Border(
                                                        top: BorderSide(color: kTextDark.withOpacity(0.15)), // ✅ 柔格線
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
                    onPressed: _isSaving ? null : _saveTrip,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? "儲存中..." : "儲存行程"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      overlayColor: kPressedTint,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                  ),
                ),
              ),
      ),
    );
  }






  /// 跳轉到撰寫或查看心得頁面
  void _showNotesAllDays({required bool viewOnly}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelNotePage(
          allDailySpots: dailySpots,
          readOnly: viewOnly,
        ),
      ),
    ).then((updatedSpots) {
      if (updatedSpots != null && mounted) {
        setState(() {
          dailySpots = List<List<Map<String, String>>>.from(updatedSpots);
          _saveNotesToStorage();
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

    if (storedNotes != null && storedNotes.isNotEmpty && storedNotes != "[]") {
      try {
        final decodedNotes = (jsonDecode(storedNotes) as List)
            .map<List<Map<String, String>>>((day) =>
                (day as List).map<Map<String, String>>((spot) =>
                    Map<String, String>.from(spot as Map)).toList()).toList();

        setState(() {
          dailySpots = decodedNotes;

          // 若不足天數就補齊
          if (dailySpots.length < dayCount) {
            dailySpots += List.generate(dayCount - dailySpots.length, (_) => []);
          }
        });

        debugPrint("✅ 成功載入 notes_$tripName，覆蓋 initialSpots");
      } catch (e) {
        debugPrint("❌ notes_$tripName 載入失敗：$e");
      }
    } else {
      debugPrint("ℹ️ 沒有有效的 notes_$tripName，保留 initialSpots");
    }
  }



  Widget _buildSpotBlock(Map<String, String> spot, int dayIndex, {bool isFeedback = false}) {
    if (!spot.containsKey('Name')) {
      debugPrint("🚨 無效景點：$spot");
      return const SizedBox();
    }

    final duration = int.tryParse(spot['Duration'] ?? '1') ?? 1;
    final name = spot['Name'] ?? '無名稱';
    final time = spot['Time'] ?? '08';

    final container = Container(
      height: duration * hourBlockHeight,
      decoration: BoxDecoration(
        color: isFeedback ? kAccent.withOpacity(0.7) : kAccent, // ✅ 奶茶點綴色
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.25)), // ✅ 淺邊框更文青
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // ✅ 柔霧陰影
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,          // ✅ 微字距
                  ),
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
          Flexible(
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
      // ✅ 拖曳中的預覽給固定寬度，避免尺寸不明
      return SizedBox(
        width: MediaQuery.of(context).size.width - 100,
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
    String imageUrl = '';
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
      print('⚠️ 圖片處理錯誤: $e');
      imageUrl = '';
    }

    showDialog(
      context: context,
      builder: (context) {
        final description = (spot['Toldescribe']?.trim().isNotEmpty ?? false)
            ? spot['Toldescribe']
            : (spot['Description'] ?? '❌ 沒有描述資料');

        return AlertDialog(
          title: Text(spot['Name'] ?? '無名稱'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350), // 避免過高
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((spot['Add'] ?? '').isNotEmpty)
                    Text("📍 ${spot['Add']}")
                  else
                    const Text("📍 無地址"),
                  const SizedBox(height: 12),
                  if (imageUrl.startsWith('http'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 16 / 9, // 穩定比例
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        ),
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
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('🧭 導航'),
            ),
            TextButton(
              onPressed: () {
                _toggleFavorite(spot);
                Navigator.pop(context);
              },
              child: Text(_isFavorited(spot) ? '⭐ 移除收藏' : '⭐ 加入收藏'),
            ),
            TextButton(
              onPressed: () {
                final longDesc = description;
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("📘 景點資訊"),
                    content: SingleChildScrollView(
                      child: Text(longDesc!),
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
        );
      },
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
                  ? kAccent.withOpacity(0.08) // ✅ 柔和拿鐵色高亮
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

    // ✅ NEW：把目前行程轉成可上傳的 JSON
  Map<String, dynamic> _buildUploadPayload() {
    // 轉成 yyyy-MM-dd
    final startDateStr = DateFormat('yyyy-MM-dd').format(widget.startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(widget.endDate);

    // 把 dailySpots 轉成更乾淨的結構（保留你現有欄位）
    final days = <Map<String, dynamic>>[];
    for (int d = 0; d < dayCount; d++) {
      final spots = (d < dailySpots.length) ? dailySpots[d] : <Map<String, String>>[];
      days.add({
        "index": d + 1,
        "date": DateFormat('yyyy-MM-dd').format(widget.startDate.add(Duration(days: d))),
        "spots": spots.map((s) => {
          "Name": s["Name"] ?? "",
          "Add": s["Add"] ?? "",
          "Px": s["Px"] ?? "",
          "Py": s["Py"] ?? "",
          "Description": s["Description"] ?? (s["Toldescribe"] ?? ""),
          "Time": s["Time"] ?? "08",
          "Duration": s["Duration"] ?? "1",
          "Raw": s["Raw"] ?? "",
          "Picture1": s["Picture1"] ?? "",
        }).toList(),
        "transports": (d < dailyTransports.length) ? dailyTransports[d] : <String>[],
      });
    }



    // 對齊你後端 sync_hfl_data 的鍵位（多的鍵後端會忽略也沒關係）
    return {
      "uid": userUid,
      "model": "gpt",
      "prompt": "save_trip_after_user_confirmed",
      "city": null, // 若你有 city 可在這裡帶
      "budget": widget.budget,
      "transport": widget.transport,
      "types": <String>[], // 若有旅遊類型就帶
      "date_range": {"start": startDateStr, "end": endDateStr},
      "parameters": {
        "trip_name": widget.tripName,
        "mood": widget.mood,
        "need": widget.need,
      },
      "itinerary": {
        "tripName": widget.tripName,
        "startDate": startDateStr,
        "endDate": endDateStr,
        "budget": widget.budget,
        "transport": widget.transport,
        "days": days,
      },
    };
  }

}
