import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String> getTravelRecommendation({
    required String city,
    required List<String> types,
    required double budget,
    required String transport,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<Map<String, String>> availableSpots,
    String mood = '',
    String need = '',
  }) async {
    try {
      print("📥 開始呼叫 GPT API...");
      String apiKey = (dotenv.maybeGet('OPENAI_API_KEY') ?? '').trim();
      if (apiKey.isEmpty) {
        apiKey = (await _storage.read(key: 'OPENAI_API_KEY') ?? '').trim();
      }
      if (apiKey.isEmpty) {
        print("❌ 無法讀取 API 金鑰（OPENAI_API_KEY）");
        return "❌ 找不到 API 金鑰，請確認 .env 與 main.dart 已載入。";
      }
      // 可選：把 dotenv 讀到的 key 回寫到 SecureStorage，之後就算沒載到 .env 也能用
      await _storage.write(key: 'OPENAI_API_KEY', value: apiKey);

      const endpoint = 'https://api.openai.com/v1/chat/completions';

      final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            "model": "gpt-3.5-turbo",
            "messages": [
              {"role": "system", "content": "你是一位專業的台灣旅遊行程規劃師，只能根據提供的景點清單安排行程，禁止產生清單以外的景點。"},
              {"role": "user", "content": _generatePrompt(
                  city: city,
                  types: types,
                  budget: budget,
                  transport: transport,
                  startDate: startDate,
                  endDate: endDate,
                  availableSpots: availableSpots,
                )
              }
            ],
            "max_tokens": 1000,
            "temperature": 0.7,
          }),
        )
        .timeout(const Duration(seconds: 60));


      print("📡 GPT 回傳狀態碼：${response.statusCode}");

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final jsonResponse = jsonDecode(decodedBody);
        final result = jsonResponse['choices'][0]['message']['content'] ?? "⚠️ GPT 回傳為空";
        print("📝 GPT 回傳前300字：${result.length > 300 ? result.substring(0, 300) + '...' : result}");
        return result;
      } else if (response.statusCode == 429) {
        print("🚫 被限流（429）：${response.body}");
        return "⚠️ 請求太頻繁或 API 額度不足，請稍後再試，或登入 OpenAI 控制台檢查配額與帳單。";
      } else {
        print("❌ 其他錯誤內容：${response.body}");
        return "❌ API 錯誤：${response.statusCode}";
      }
    } catch (e) {
      print("❌ 發生例外錯誤：$e");
      return "❌ 發生例外錯誤：$e";
    }
  }

  String _generatePrompt({
    required String city,
    required List<String> types,
    required double budget,
    required String transport,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<Map<String, String>> availableSpots,
    String mood = '',
    String need = '',
  }) {
    final dateInfo = (startDate != null && endDate != null)
        ? "從 ${DateFormat('yyyy/MM/dd').format(startDate)} 到 ${DateFormat('yyyy/MM/dd').format(endDate)}"
        : "無指定日期";

    final firstDayStr = startDate != null
        ? DateFormat('yyyy/MM/dd').format(startDate)
        : "2025/07/01"; // 預設日期

    final typesList = types.isNotEmpty ? types.join(", ") : "不拘";

    final scenicSpots = availableSpots
        .where((s) => s['Type'] == '景點')
        .map((s) =>
            "【${s['Name']}】（${s['Category'] ?? '未知類型'}，${s['Region'] ?? '未知地區'}）")
        .where((n) => n.trim().isNotEmpty)
        .toSet()
        .take(100)
        .toList();

    final foodSpots = availableSpots
        .where((s) => s['Type'] == '美食')
        .map((s) =>
            "【${s['Name']}】（美食，${s['Region'] ?? '未知地區'}）")
        .where((n) => n.trim().isNotEmpty)
        .toSet()
        .take(50)
        .toList();

    final joinedSpots = [...scenicSpots, ...foodSpots].join("、");

    return """
  我正在規劃一趟台灣的旅遊行程，地點為：$city，旅遊日期：$dateInfo。
  每日預算為每人 NT\$${budget.toInt()} 元，使用交通方式：$transport。
  我偏好的旅遊類型有：$typesList。

  目前心情：「$mood」，這次旅行我希望：「$need」。

  ⚠️ 請特別注意以下需求：
  - 若提到「不想曬太陽」，請避免安排炎熱或缺乏遮蔭的戶外景點。
  - 若提到「不想人擠人」，請避開熱門地點，改安排冷門、安靜的地方。
  - 若提到「想放鬆」或「壓力大」，請安排節奏緩慢、寧靜的景點。

  ✅ 以下是可選地點（**只能從這些景點與美食中安排**）：
  $joinedSpots

  📌 安排行程時，請**每天規劃從上午 9:00 到晚上 7:00 的完整旅遊行程**，包含：
  - 景點參訪與活動
  - 餐食安排（建議每日安排中餐與晚餐各一間「美食」地點）
  - 交通方式（捷運、公車、走路等）
  - 景點順序要合理，避免跳點與長距離來回移動

  📋 請使用以下格式回覆，**不要加任何說明文字**：

  Day 1（$firstDayStr）：
  09:00 ~ 10:00  
  景點：xx公園  
  活動：散步、欣賞風景  
  交通：捷運到達

  10:00 ~ 12:00  
  景點：某某老街  
  活動：逛街購物  
  交通：步行

  12:00 ~ 13:00  
  景點：老王牛肉麵（美食）  
  活動：午餐  
  交通：步行

  ...

  請根據日期逐日列出完整時段行程，確保內容合理、有趣且符合需求。
  """;
  }


}
