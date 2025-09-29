import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel/hfl_model.dart';

class HFLClient {
  final String baseUrl;
  final String uid;

  HFLClient({required this.baseUrl, required this.uid});

  Future<dynamic> pushUpdate(LRModel model, int numExamples, {int round = 1}) async {
    final payload = {
      "client_id": uid,
      "num_examples": numExamples,
      "round": round,
      "weights": model.toJson(),
    };

    final res = await http.post(
      Uri.parse('$baseUrl/hfl/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HFL 伺服器錯誤: ${res.statusCode} ${res.body}');
    }

    if (res.body.isEmpty) {
      // 200 OK 但沒回應 → 當成功處理，但沒新權重
      return null;
    }

    try {
      final m = jsonDecode(res.body);

      if (m is Map<String, dynamic>) {
        // ✅ 如果有傳全域模型，就載入覆蓋
        if (m.containsKey('weights') && m['weights'] is Map<String, dynamic>) {
          final gw = m['weights'] as Map<String, dynamic>;
          model.load(gw);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('hfl_model_lr_v1', jsonEncode(model.toJson()));
        }
        return m;
      } else {
        // 後端回了非 Map 的 JSON（例如 List）
        return m;
      }
    } catch (_) {
      // 回傳不是 JSON → 直接傳回原始字串
      return res.body;
    }
  }

}
