import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

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
      final apiKey = await _storage.read(key: 'OPENAI_API_KEY');

      if (apiKey == null || apiKey.isEmpty) {
        print("❌ 無法讀取 API 金鑰！");
        return "❌ 找不到 API 金鑰，請確認 main.dart 是否有正確設定。";
      }

      const endpoint = 'https://api.openai.com/v1/chat/completions';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "gpt-3.5-turbo",
          "messages": [
            {
              "role": "system",
              "content": "你是一位專業的台灣旅遊行程規劃師，只能根據提供的景點清單安排行程，禁止產生清單以外的景點。"
            },
            {
              "role": "user",
              "content": _generatePrompt(
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
      );

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

    final typesList = types.isNotEmpty ? types.join(", ") : "不拘";

    final spotNames = availableSpots
        .map((s) => s['Name'])
        .whereType<String>()
        .where((n) => n.trim().isNotEmpty)
        .toSet()
        .take(100)
        .toList();

    final joinedSpots = spotNames.join("、");

    return """
  我正在規劃一趟台灣的旅遊行程，地點是 $city。我的預算是每人 NT\$${budget.toInt()}，旅遊日期為：$dateInfo。
  我希望的交通方式是：$transport。
  我偏好的行程類型有：$typesList。

  目前我的心情是：「$mood」，我特別希望這次旅程能夠：「$need」。

  ⚠️ 請務必根據以下偏好做出安排：
  - 若提到「不想曬太陽」，請避免安排戶外、炎熱、缺乏遮蔽的景點（如古道、登山、牧場、沙灘等），改安排有遮蔽、室內、或傍晚的行程。
  - 若提到「不想人擠人」，請避免安排熱門或擁擠的地點，改安排冷門、寧靜、有座位的空間。
  - 若提到「想放鬆」或「壓力大」，請安排節奏較慢的景點，例如美術館、書店、溫泉、咖啡廳、森林步道等。

  請根據以下可用的景點清單規劃，**只能選用下列景點名稱**：$joinedSpots。

  請幫我規劃三日的旅遊行程，格式如下：
  Day 1：
    上午：地點名稱 - 簡短說明
    下午：地點名稱 - 簡短說明
    晚上：地點名稱 - 簡短說明

  Day 2：
  ...

  請注意行程動線的合理性與預算控制。不要有廢話解釋，只回傳行程即可。
  """;
  }


}
