import 'package:flutter/material.dart';
import 'package:travel/ai_recommend_result_page.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:travel/openai_service.dart';

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
  String selectedCategory = "景點";
  List<Map<String, String>> spots = [];
  
  bool isLoading = false;
  String? recommendationResult;

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
    final fileName = selectedCategory == "景點"
        ? 'assets/data/ScenicSpot.csv'
        : 'assets/data/Restaurant.csv';
    final rawData = await rootBundle.loadString(fileName);
    final csvRows = const CsvToListConverter().convert(rawData);
    final headers = csvRows.first.map((e) => e.toString()).toList();

    final data = csvRows.skip(1).map((row) {
      return Map<String, String>.fromIterables(
        headers,
        row.map((e) => e.toString()),
      );
    }).toList();

    setState(() {
      spots = data;
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

    final filteredSpots = spots.where((spot) {
      if (selectedCity != null && spot['Region'] != selectedCity) return false;
      if (selectedTypes.isNotEmpty) {
        return selectedTypes.any((type) => spot['Category']?.contains(type) ?? false);
      }
      return true;
    }).toList();

    try {
      final gptResult = await openAIService
          .getTravelRecommendation(
            city: selectedCity!,
            types: selectedTypes,
            budget: budget,
            transport: transport,
            startDate: startDate,
            endDate: endDate,
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

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AIRecommendResultPage(
            spots: filteredSpots,
            city: selectedCity,
            budget: budget,
            transport: transport,
            types: selectedTypes,
            startDate: startDate,
            endDate: endDate,
            gptRecommendation: recommendationResult,
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
                Navigator.pop(context); // 關閉 dialog
                _startRecommendation(); // 🔁 重新呼叫
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
              const Text('選擇推薦類別'),
              DropdownButton<String>(
                value: selectedCategory,
                items: const [
                  DropdownMenuItem(value: "景點", child: Text("景點")),
                  DropdownMenuItem(value: "美食", child: Text("美食")),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value!;
                    _loadSpots();
                  });
                },
              ),
              const SizedBox(height: 16),
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
}


