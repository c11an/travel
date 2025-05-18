import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OpenAIService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String> getTravelRecommendation({
    required String city,
    required List<String> types,
    required double budget,
    required String transport,
    required DateTime? startDate,
    required DateTime? endDate,
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
              "content": "你是一位專業的台灣旅遊行程規劃師，請根據使用者輸入推薦每日的早上、下午、晚上安排。"
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
              )
            }
          ],
          "max_tokens": 1000,
          "temperature": 0.7,
        }),
      );

      print("📡 GPT 回傳狀態碼：${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
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
  }) {
    final dateInfo = (startDate != null && endDate != null)
        ? "從 ${startDate.toLocal().toString().split(' ')[0]} 到 ${endDate.toLocal().toString().split(' ')[0]}"
        : "無指定日期";
    final typesList = types.isNotEmpty ? types.join(", ") : "不拘";

    return """
我正在規劃一趟旅遊，地點是 $city。我的預算是每人 $budget 元。
我希望行程包含以下類型：$typesList。
我希望的交通方式是：$transport。
旅遊日期為：$dateInfo。

請幫我規劃一份每日行程表，格式如下：
Day 1：
  上午：
  下午：
  晚上：
Day 2：
...

每個景點請簡短說明特色，並考慮旅遊動線與預算。
""";
  }
}
