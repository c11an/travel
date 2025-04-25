// lib/ai_recommend_page.dart
import 'package:flutter/material.dart';
import 'package:travel/ai_recommend_result_page.dart';

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

  // ✅ 直接照台灣常見縣市順序
  final List<String> cities = [
    "基隆市",
    "臺北市",
    "新北市",
    "桃園市",
    "新竹市",
    "新竹縣",
    "苗栗縣",
    "臺中市",
    "彰化縣",
    "南投縣",
    "雲林縣",
    "嘉義市",
    "嘉義縣",
    "臺南市",
    "高雄市",
    "屏東縣",
    "宜蘭縣",
    "花蓮縣",
    "臺東縣",
    "澎湖縣",
    "金門縣",
    "連江縣",
  ];

  final List<String> transportOptions = ['不拘', '火車/高鐵', '汽車', '機車'];
  final List<String> travelTypes = ['自然景點', '文化體驗', '美食之旅', '放鬆休閒'];

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('出發地（縣市）', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedCity,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '選擇縣市',
              ),
              items: cities.map((city) {
                return DropdownMenuItem(
                  value: city,
                  child: Text(city),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCity = value;
                });
              },
            ),
            const SizedBox(height: 16),
            const Text('出發與結束日期', style: TextStyle(fontSize: 16)),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _selectDate(context, true),
                  child: Text(startDate == null
                      ? '選擇出發日'
                      : "${startDate!.year}/${startDate!.month}/${startDate!.day}"),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _selectDate(context, false),
                  child: Text(endDate == null
                      ? '選擇結束日'
                      : "${endDate!.year}/${endDate!.month}/${endDate!.day}"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('預算範圍', style: TextStyle(fontSize: 16)),
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
            const Text('交通方式', style: TextStyle(fontSize: 16)),
            DropdownButton<String>(
              value: transport,
              isExpanded: true,
              items: transportOptions.map((String value) {
                return DropdownMenuItem(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  transport = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),
            const Text('旅遊類型', style: TextStyle(fontSize: 16)),
            Wrap(
              spacing: 8.0,
              children: travelTypes.map((type) {
                final isSelected = selectedTypes.contains(type);
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
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
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AIRecommendResultPage(
                        city: selectedCity,
                        budget: budget,
                        transport: transport,
                        types: selectedTypes,
                      ),
                    ),
                  );
                },
                child: const Text('開始推薦行程'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
