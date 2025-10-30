import 'package:flutter/material.dart';
import 'package:travel/ai_recommend_result_page.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:travel/openai_service.dart';

// ===== 全站統一：奶茶文青風配色 =====
const kBgCream     = Color(0xFFFAF3E0); // 背景：淡奶茶米色
const kCardBase    = Color(0xFFEAD7B7); // 卡片 / 輸入底
const kPressedTint = Color(0xFFD6C2A1); // 按下 hover
const kTextDark    = Color(0xFF4E342E); // 深棕文字
const kAccent      = Color(0xFFB48A60); // 拿鐵咖啡主色

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

    final scenicHeader = scenicRows.first.map((e) => e.toString()).toList();
    final foodHeader = foodRows.first.map((e) => e.toString()).toList();

    final scenicData = scenicRows.skip(1).map((row) {
      return Map<String, String>.fromIterables(
        scenicHeader,
        row.map((e) => e.toString()),
      )..['Type'] = '景點';
    }).toList();

    final foodData = foodRows.skip(1).map((row) {
      return Map<String, String>.fromIterables(
        foodHeader,
        row.map((e) => e.toString()),
      )..['Type'] = '美食';
    }).toList();

    final combined = [...scenicData, ...foodData];

    setState(() {
      allSpots = combined;
      spots = combined;
    });

    print("✅ 讀取景點成功，共 ${combined.length} 筆");
  }

  // 依名稱 / 描述 / Category 粗略判斷是否符合使用者選的「旅遊類型」
  bool _matchUserType(Map<String, String> spot, List<String> selectedTypes) {
    if (selectedTypes.isEmpty) return true; // 沒選就不過濾

    final typeField = (spot['Type'] ?? '');        // 你在 _loadSpots 有標 '景點' / '美食'
    final category  = (spot['Category'] ?? '');    // 若 CSV 有分類欄位可用，沒有也沒關係
    final name      = (spot['Name'] ?? '');
    final desc      = (spot['Description'] ?? '');
    final text = '$typeField|$category|$name|$desc';

    bool isNature() => RegExp(r'自然|山|步道|森林|瀑布|湖|海|沙灘|溫泉|綠地|公園').hasMatch(text);
    bool isCulture() => RegExp(r'文化|博物館|美術館|寺|廟|宮|古蹟|展覽|文創|老街').hasMatch(text);
    bool isFood()    => typeField.contains('美食') || RegExp(r'餐|小吃|夜市|美食|咖啡|甜點').hasMatch(text);
    bool isRelax()   => RegExp(r'溫泉|公園|海邊|湖畔|步道|草地|休閒|放鬆|風景').hasMatch(text);

    for (final t in selectedTypes) {
      switch (t) {
        case '自然景點': if (isNature()) return true; break;
        case '文化體驗': if (isCulture()) return true; break;
        case '美食之旅': if (isFood())   return true; break;
        case '放鬆休閒': if (isRelax())  return true; break;
      }
    }
    return false;
  }




  void _startRecommendation() async {
    final openAIService = OpenAIService();
    if (selectedCity == null) {
      _showSnack('請選擇縣市', isError: true);
      return;
    }

    if (startDate == null || endDate == null) {
      _showSnack('請選擇出發及結束日期', isError: true);
      return;
    }


    print("🚀 開始推薦");
    setState(() => isLoading = true);

    // ① 先用城市過濾
    final cityFiltered = allSpots.where((s) => s['Region'] == selectedCity).toList();

    // ② 依使用者選的旅遊類型做語意過濾（景點/美食都判斷）
    List<Map<String, String>> candidates =
        cityFiltered.where((s) => _matchUserType(s, selectedTypes)).toList();

        if (candidates.isEmpty) {
          setState(() => isLoading = false);
          _showSnack('目前條件下找不到景點，請更換縣市或放寬類型', isError: true);
          return;
        }


    String relaxNote = '';
    // ③ 候選太少就放寬：先放寬類型，只保留城市
    if (candidates.length < 8) {
      candidates = cityFiltered;
      relaxNote = '已放寬「旅遊類型」條件';
    }
    if (candidates.length < 5) {
      _showSnack('⚠️ 可用景點較少（${candidates.length}）$relaxNote', isError: true);
    }
    candidates.shuffle();


    try {
      // ④ 把過濾後的候選清單交給 GPT（只給看這些）
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
            availableSpots: candidates, // ← 關鍵
          )
          .timeout(const Duration(seconds: 20), onTimeout: () {
        print("⚠️ GPT API 請求逾時");
        _showSnack('⚠️ ChatGPT 回應逾時，請稍後再試', isError: true);
        return "⚠️ ChatGPT 回應逾時，請稍後再試";

      });

      print("✅ GPT 結果長度：${gptResult.length}");
      print("📝 前300字：${gptResult.substring(0, gptResult.length > 300 ? 300 : gptResult.length)}");

      setState(() {
        isLoading = false;
        recommendationResult = gptResult;
      });

      // ⑤ 解析時也用同一份 candidates，避免對不到資料或類型跑偏
      final dailySpots = parseGptTextToDailySpots(gptResult, candidates);

      // （可選）post-check：把不在候選清單中的名稱剔除
      final candNames = candidates.map((s) => s['Name']).whereType<String>().toSet();
      for (final day in dailySpots) {
        day.removeWhere((spot) => !candNames.contains(spot['Name']));
      }

      if (dailySpots.isEmpty) {
       _showSnack('GPT 沒產出有效行程，請放寬條件或重試', isError: true);
        return;
      }

      // ⑥ 跳結果頁也帶 candidates，保持一致
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
            allSpots: candidates, // ← 改這裡
            mood: _moodController.text.trim(),
            need: _needController.text.trim(),
          ),
        ),
      );

    } catch (e) {
      print("❌ 發生錯誤：$e");
      setState(() => isLoading = false);
      showDialog(
        context: context,
        builder: (_) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kAccent,        // 拿鐵主色
              onPrimary: Colors.white, // 按鈕文字
              surface: kCardBase,      // 對話框底
              onSurface: kTextDark,    // 一般文字
            ),
          ),
          child: AlertDialog(
            backgroundColor: kCardBase,
            title: const Text('錯誤', style: TextStyle(color: kTextDark, fontWeight: FontWeight.bold)),
            content: Text('無法獲得推薦行程：$e', style: const TextStyle(color: kTextDark)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: kAccent)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startRecommendation();
                },
                child: const Text('重新推薦', style: TextStyle(color: kAccent)),
              ),
            ],
          ),
        ),
      );

    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? Colors.redAccent.withOpacity(0.85) : kAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),

      // 🟤 奶茶風主題覆寫
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kAccent,        // 主色（拿鐵咖啡）
              onPrimary: Colors.white, // 主色文字
              surface: kCardBase,      // 對話框背景：奶茶棕
              onSurface: kTextDark,    // 主要文字：深棕
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: kAccent, // 日期選擇按鈕（例如取消/確定）
              ),
            ),
          ),
          child: child!,
        );
      },
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
    backgroundColor: kBgCream,
    appBar: AppBar(
      backgroundColor: kBgCream,
      elevation: 0,
      iconTheme: const IconThemeData(color: kTextDark),
      title: const Text(
        'AI行程推薦',
        style: TextStyle(color: kTextDark, fontWeight: FontWeight.bold),
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('行程名稱', style: TextStyle(color: kTextDark, fontWeight: FontWeight.w600)),
            TextField(
              controller: _tripNameController,
              style: const TextStyle(color: kTextDark),
              decoration: InputDecoration(
                filled: true,
                fillColor: kCardBase.withOpacity(0.6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: '輸入這趟旅程的名稱，例如：暑假小旅行',
                hintStyle: const TextStyle(color: kTextDark),
              ),
            ),

            const SizedBox(height: 16),
            const Text('出發地（縣市）', style: TextStyle(color: kTextDark, fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kCardBase.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: selectedCity,
                isExpanded: true,
                dropdownColor: kCardBase,
                iconEnabledColor: kTextDark,
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: kTextDark),
                items: cities.map((city) => DropdownMenuItem(
                  value: city,
                  child: Text(city),
                )).toList(),
                onChanged: (value) => setState(() => selectedCity = value),
              ),
            ),

            const SizedBox(height: 16),
            const Text('出發日期和結束日期', style: TextStyle(color: kTextDark, fontWeight: FontWeight.w600)),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _selectDate(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLoading ? kPressedTint : kAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(startDate == null ? '選擇出發日' : DateFormat('yyyy/MM/dd').format(startDate!)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _selectDate(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(endDate == null ? '選擇結束日' : DateFormat('yyyy/MM/dd').format(endDate!)),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Text('旅遊類型', style: TextStyle(color: kTextDark, fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              children: ['自然景點', '文化體驗', '美食之旅', '放鬆休閒'].map((type) {
                final selected = selectedTypes.contains(type);
                return ChoiceChip(
                  label: Text(
                    type,
                    style: TextStyle(color: selected ? Colors.white : kTextDark),
                  ),
                  selected: selected,
                  selectedColor: kAccent,
                  backgroundColor: kCardBase.withOpacity(0.85),
                  onSelected: (isSel) {
                    setState(() {
                      if (isSel) {
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
                child: Text('已選：${selectedTypes.join("、")}',
                    style: const TextStyle(color: kTextDark)),
              ),

            const SizedBox(height: 16),
            const Text('預算範圍 (NT\$)', style: TextStyle(color: kTextDark, fontWeight: FontWeight.w600)),
            Slider(
              value: budget,
              min: 1000,
              max: 20000,
              divisions: 19,
              label: budget.round().toString(),
              activeColor: kAccent,
              inactiveColor: kPressedTint,
              onChanged: (value) => setState(() => budget = value),
            ),

            const SizedBox(height: 16),
            const Text('今天的心情', style: TextStyle(color: kTextDark, fontWeight: FontWeight.w600)),
            TextField(
              controller: _moodController,
              style: const TextStyle(color: kTextDark),
              decoration: InputDecoration(
                filled: true,
                fillColor: kCardBase.withOpacity(0.6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: '例如：放鬆、熱血、壓力大',
                hintStyle: const TextStyle(color: kTextDark),
              ),
            ),

            const SizedBox(height: 16),
            const Text('有什麼需求或偏好嗎？', style: TextStyle(color: kTextDark, fontWeight: FontWeight.w600)),
            TextField(
              controller: _needController,
              style: const TextStyle(color: kTextDark),
              decoration: InputDecoration(
                filled: true,
                fillColor: kCardBase.withOpacity(0.6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: '例如：想泡溫泉、不想曬太陽、不想人擠人',
                hintStyle: const TextStyle(color: kTextDark),
              ),
            ),

            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: isLoading ? null : _startRecommendation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: isLoading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
  @override
  void dispose() {
    _moodController.dispose();
    _needController.dispose();
    _tripNameController.dispose();
    super.dispose();
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


