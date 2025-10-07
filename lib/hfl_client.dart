import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/hfl_model.dart';
import 'package:flutter/foundation.dart'; // ✅ for debugPrint

class HFLClient {
  final String baseUrl;
  final String uid;

  HFLClient({required this.baseUrl, required this.uid});

  Future<dynamic> pushUpdate(LRModel model, int numExamples, {int round = 1}) async {
    debugPrint("🚀 [HFL] 準備推送本地模型更新...");
    debugPrint("🧩 Client ID: $uid");
    debugPrint("🔢 樣本數: $numExamples, 第 $round 輪");
    debugPrint("🌐 目標端點: $baseUrl/hfl/update");

    // 準備 payload
    final payload = {
      "client_id": uid,
      "num_examples": numExamples,
      "round": round,
      "weights": model.toJson(),
    };

    try {
      // 顯示部分 payload 以避免太長
      debugPrint("📦 傳送資料片段: ${jsonEncode(payload).substring(0, 150)}...");

      final res = await http.post(
        Uri.parse('$baseUrl/hfl/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint("📥 收到伺服器回應狀態碼: ${res.statusCode}");

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint("❌ [HFL] 伺服器錯誤: ${res.statusCode} ${res.body}");
        throw Exception('HFL 伺服器錯誤: ${res.statusCode}');
      }

      if (res.body.isEmpty) {
        debugPrint("⚠️ [HFL] 伺服器未回傳任何資料（200 OK 無內容）");
        return null;
      }

      final decoded = jsonDecode(res.body);
      debugPrint("🧠 [HFL] 回傳資料型態: ${decoded.runtimeType}");

      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('weights') && decoded['weights'] is Map<String, dynamic>) {
          final gw = decoded['weights'] as Map<String, dynamic>;
          debugPrint("🌍 [HFL] 收到全域模型權重，準備覆蓋本地模型...");
          model.load(gw);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('hfl_model_lr_v1', jsonEncode(model.toJson()));
          debugPrint("💾 [HFL] 全域模型已存入 SharedPreferences");
        } else {
          debugPrint("ℹ️ [HFL] 沒有收到新的全域模型權重");
        }
        debugPrint("✅ [HFL] 更新完成（status 200）");
        return decoded;
      } else {
        debugPrint("⚠️ [HFL] 非預期格式的回傳資料: $decoded");
        return decoded;
      }
    } catch (e, stack) {
      debugPrint("💥 [HFL] 發生例外: $e");
      debugPrint("🔍 Stack Trace: $stack");
      rethrow;
    }
  }
}
