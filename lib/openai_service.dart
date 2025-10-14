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
      await _storage.write(key: 'OPENAI_API_KEY', value: apiKey);

      const endpoint = 'https://api.openai.com/v1/chat/completions';

      final body = jsonEncode({
        "model": "gpt-3.5-turbo", // 若你有 gpt-4o-mini，可改成 "gpt-4o-mini"
        "messages": [
          {
            "role": "system",
            "content":
                "你是專業的台灣旅遊行程規劃師。嚴格依照提供的白名單安排行程，禁止創造白名單以外的景點或餐廳。若白名單不足，請減少每天景點數量，不得編造或替換。輸出必須完全符合使用者要求的格式（Day n、時間區間、'景點：'前綴）。"
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
              mood: mood,
              need: need,
            )
          }
        ],
        "max_tokens": 1100,
        "temperature": 0.3,         // 更一致、較不亂
        "presence_penalty": 0.0,
        "frequency_penalty": 0.0,
      });

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: body,
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
        : "2025/07/01";

    // day count（用來提醒每天數量；實際輸出仍由模型排程）
    int dayCount = 1;
    if (startDate != null && endDate != null) {
      dayCount = endDate!.difference(startDate!).inDays + 1;
      if (dayCount < 1) dayCount = 1;
    }

    final typesLine = types.isNotEmpty ? types.join("、") : "不拘";

    // 白名單：只提供名稱，減少 tokens。各自限制長度。
    final scenicNames = availableSpots
        .where((s) => s['Type'] == '景點')
        .map((s) => (s['Name'] ?? '').trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .take(60)
        .toList();

    final foodNames = availableSpots
        .where((s) => s['Type'] == '美食')
        .map((s) => (s['Name'] ?? '').trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .take(40)
        .toList();

    final scenicList = scenicNames.join("、");
    final foodList = foodNames.join("、");
    // ✅ 避免清單為空，給 GPT 明確提示「無」不要編造
    final scenicLine = scenicList.isEmpty ? "（無）" : scenicList;
    final foodLine   = foodList.isEmpty   ? "（無）" : foodList;


    // 預算：你前端是整體金額，我們給模型一個指引；若要更嚴格，可以把前端做成 tier 再加描述
    final budgetGuide = "整體每日人均預算約 NT\$${budget.toInt()}，請盡量安排符合此預算的景點與餐食（如門票、餐費）。";

    return """
  我正在規劃 $city 的旅遊行程，旅遊日期：$dateInfo（共 $dayCount 天）。
  交通方式：$transport。偏好旅遊類型：$typesLine。心情：「$mood」。需求：「$need」。
  $budgetGuide

  【白名單（只能使用以下名稱；不足就少排，不得編造新名稱）】
  - 景點清單：$scenicLine
  - 美食清單：$foodLine

  【排程原則】
  - 嚴格只從白名單挑選景點/餐廳；若白名單不足，請減少每天景點數量，不要創造白名單外的名稱。
  - 優先符合「$typesLine」與預算；動線合理，避免遠距離來回。
  - 若某類白名單為空（標示「（無）」），請略過該類型，不要創造名稱以補足。
  - 每天建議安排 2~4 個景點，並盡量包含中餐與晚餐（從美食清單挑）。
  - 若使用者提到「不想曬太陽」請避免炎熱、無遮蔭的戶外；「不想人擠人」請避開熱門、改冷門放鬆點；「想放鬆/壓力大」請節奏緩慢、寧靜。

  【輸出格式（務必嚴格遵守；不要加多餘說明文字）】
  Day 1（$firstDayStr）：
  09:00 ~ 10:30
  景點：XXXX

  10:45 ~ 12:00
  景點：YYYY

  12:00 ~ 13:00
  景點：ZZZZ（美食）

  （之後依此格式繼續到 Day $dayCount。每段必須先時間區間，下一行以「景點：」開頭，名稱必須出自白名單）
    每個區塊必須連續三行：時間區間、下一行以「景點：」開頭的名稱；不要插入額外空行或描述。

  """;
  }



}
