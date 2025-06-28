import 'package:flutter/material.dart';
import 'package:travel/ai_recommend_result_page.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:travel/openai_service.dart';
import 'package:travel/travel_day_page.dart';

class AIRecommendPage extends StatefulWidget {
  const AIRecommendPage({super.key});

  @override
  State<AIRecommendPage> createState() => _AIRecommendPageState();
}

class _AIRecommendPageState extends State<AIRecommendPage> {
  String? selectedCity;
  DateTime? startDate;
  DateTime? endDate;
  double budget = 5000;
  String transport = '不拘';
  List<String> selectedTypes = [];
  List<Map<String, String>> spots = [];
  List<Map<String, String>> allSpots = []; // 🔧 全部資料

  
  bool isLoading = false;
  String? recommendationResult;

  final TextEditingController _moodController = TextEditingController();
  final TextEditingController _needController = TextEditingController();
  final TextEditingController _tripNameController = TextEditingController();



  final List<String> cities = [
    "基隆市", "臺北市", "新北市", "桃園市", "新竹市",
    "新竹縣", "苗栗縣", "臺中市", "彰化縣", "南投縣",
    "雲林縣", "嘉義市", "嘉義縣", "臺南市", "高雄市",
    "屏東縣", "宜蘭縣", "花蓮縣", "臺東縣",
    "澎湖縣", "金門縣", "連江縣",
  ];

  @override
  void initState() {
    super.initState();
    _loadSpots();
  }

  Future<void> _loadSpots() async {
    final scenicRaw = await rootBundle.loadString('assets/data/ScenicSpot.csv');
    final foodRaw = await rootBundle.loadString('assets/data/Restaurant.csv');

    final csvConverter = const CsvToListConverter();

    final scenicRows = csvConverter.convert(scenicRaw);
    final foodRows = csvConverter.convert(foodRaw);

    final headers = scenicRows.first.map((e) => e.toString()).toList();

    final scenicData = scenicRows.skip(1).map((row) {
      return Map<String, String>.fromIterables(
        headers,
        row.map((e) => e.toString()),
      )..['Type'] = '景點';
    }).toList();

    final foodData = foodRows.skip(1).map((row) {
      return Map<String, String>.fromIterables(
        headers,
        row.map((e) => e.toString()),
      )..['Type'] = '美食';
    }).toList();

    final combined = [...scenicData, ...foodData];

    setState(() {
      allSpots = combined;
      spots = combined;
    });
  }


  void _startRecommendation() async {
    final openAIService = OpenAIService();
    if (selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇縣市')),
      );
      return;
    }

    print("🚀 開始推薦");

    setState(() {
      isLoading = true;
    });

    final filteredSpots = allSpots.where((spot) {
      if (spot['Region'] != selectedCity) return false;
      if (selectedTypes.isNotEmpty) {
        return selectedTypes.any((type) => spot['Category']?.contains(type) ?? false);
      }
      return true;
    }).toList();


    if (filteredSpots.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 可用景點太少，建議更換縣市或旅遊類型')),
      );
    }

    try {
      final gptResult = await openAIService
          .getTravelRecommendation(
            city: selectedCity!,
            types: selectedTypes,
            budget: budget,
            transport: transport,
            startDate: startDate,
            endDate: endDate,
            mood: _moodController.text.trim(),
            need: _needController.text.trim(),
            availableSpots: allSpots.where((spot) => spot['Region'] == selectedCity).toList(),
          )
          .timeout(const Duration(seconds: 20), onTimeout: () {
        print("⚠️ GPT API 請求逾時");
        return "⚠️ ChatGPT 回應逾時，請稍後再試";
      });

      print("✅ GPT 結果長度：${gptResult.length}");
      print("📝 前300字：${gptResult.substring(0, gptResult.length > 300 ? 300 : gptResult.length)}");

      setState(() {
        isLoading = false;
        recommendationResult = gptResult;
      });

      // ✅ 將 GPT 回傳內容轉成 dailySpots 格式
      final dailySpots = parseGptTextToDailySpots(
        gptResult,
        allSpots.where((s) => s['Region'] == selectedCity).toList(),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AIRecommendResultPage(
            tripName: _tripNameController.text.trim(),
            startDate: startDate ?? DateTime.now(),
            endDate: endDate ?? DateTime.now(),
            budget: budget,
            transport: transport,
            gptRecommendation: gptResult,
            allSpots: allSpots.where((s) => s['Region'] == selectedCity).toList(),
            mood: _moodController.text.trim(),
            need: _needController.text.trim(),
          ),
        ),
      );

    } catch (e) {
      print("❌ 發生錯誤：$e");
      setState(() {
        isLoading = false;
      });
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('錯誤'),
          content: Text('無法獲得推薦行程：$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startRecommendation();
              },
              child: const Text('重新推薦'),
            ),
          ],
        ),
      );
    }
  }



  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = null;
          }
        } else {
          endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI行程推薦')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('行程名稱'),
              TextField(
                controller: _tripNameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '輸入這趟旅程的名稱，例如：暑假小旅行',
                ),
              ),
              SizedBox(height: 16),
              const Text('出發地（縣市）'),
              DropdownButton<String>(
                value: selectedCity,
                items: cities.map((city) => DropdownMenuItem(
                  value: city,
                  child: Text(city),
                )).toList(),
                onChanged: (value) => setState(() => selectedCity = value),
              ),
              const SizedBox(height: 16),
              const Text('出發日期和結束日期'),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(startDate == null ? '選擇出發日' : DateFormat('yyyy/MM/dd').format(startDate!)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(endDate == null ? '選擇結束日' : DateFormat('yyyy/MM/dd').format(endDate!)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('旅遊類型'),
              Wrap(
                spacing: 8,
                children: ['自然景點', '文化體驗', '美食之旅', '放鬆休閒'].map((type) {
                  return ChoiceChip(
                    label: Text(type),
                    selected: selectedTypes.contains(type),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedTypes.add(type);
                        } else {
                          selectedTypes.remove(type);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              if (selectedTypes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('已選：${selectedTypes.join("、")}'),
              ),

              const SizedBox(height: 16),
              const Text('預算範圍 (NT\$)'),
              Slider(
                value: budget,
                min: 1000,
                max: 20000,
                divisions: 19,
                label: budget.round().toString(),
                onChanged: (value) {
                  setState(() {
                    budget = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('今天的心情'),
              TextField(
                controller: _moodController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '例如：放鬆、熱血、壓力大',
                ),
              ),

              const SizedBox(height: 16),
              const Text('有什麼需求或偏好嗎？'),
              TextField(
                controller: _needController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '例如：想泡溫泉、不想曬太陽、不想人擠人',
                ),
              ),
              
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: isLoading ? null : _startRecommendation,
                  child: isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('推薦中，請稍候...'),
                      ],
                    )
                  : const Text('開始推薦行程'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<List<Map<String, String>>> parseGptTextToDailySpots(String gptText, List<Map<String, String>> allSpots) {
    final lines = gptText.split('\n');
    List<List<Map<String, String>>> result = [];
    List<Map<String, String>> currentDaySpots = [];

    final dayRegex = RegExp(r'^Day\s*\d+');
    final timeRegex = RegExp(r'^(\d{1,2}:\d{2})\s*~\s*(\d{1,2}:\d{2})$');

    String? currentTimeStart;

    for (final line in lines) {
      final trimmed = line.trim();

      if (dayRegex.hasMatch(trimmed)) {
        if (currentDaySpots.isNotEmpty) {
          result.add(currentDaySpots);
          currentDaySpots = [];
        }
      } else if (timeRegex.hasMatch(trimmed)) {
        currentTimeStart = trimmed.split('~').first.trim();
      } else if (trimmed.startsWith('景點：')) {
        final name = trimmed.replaceFirst('景點：', '').trim();
        final spot = allSpots.firstWhere(
          (s) => s['Name'] == name,
          orElse: () => {
            'Name': name,
            'Add': '',
            'Px': '0',
            'Py': '0',
            'Description': '',
          },
        );

        final hourStr = currentTimeStart?.split(':').first.padLeft(2, '0') ?? '08';

        currentDaySpots.add({
          'Name': spot['Name'] ?? '',
          'Add': spot['Add'] ?? '',
          'Px': spot['Px'] ?? '0',
          'Py': spot['Py'] ?? '0',
          'Description': spot['Description'] ?? '',
          'Time': hourStr,
          'Duration': '2', // 預設兩小時，如需更精細可以擴充時間解析
        });
      }
    }

    if (currentDaySpots.isNotEmpty) {
      result.add(currentDaySpots);
    }

    return result;
  }

}


