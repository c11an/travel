import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({String? overrideBase})
      : base = (overrideBase ?? dotenv.get('BACKEND_BASE_URL', fallback: '')).trim();

  final String base;

  /// 🔑 自動處理 base + path，確保無論結尾/開頭斜線都正確
  Uri _u(String path, [Map<String, String>? q]) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$b$p').replace(queryParameters: q);
  }

  /// 基本 POST JSON
  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final resp = await http
        .post(
          _u(path),
          headers: const {
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    // 不是 200~299 → 丟錯，避免你把 HTML 當 JSON
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    try {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('回傳不是有效 JSON: ${resp.body}');
    }
  }

  /// === API 包裝 ===

  /// AI 推薦
  Future<Map<String, dynamic>> recommend({
    required String city,
    required int budget,
    required String transport,
    required List<String> types,
  }) {
    return postJson('/api/recommend', {
      'city': city,
      'budget': budget,
      'transport': transport,
      'types': types,
    });
  }

  /// HFL 更新
  Future<Map<String, dynamic>> hflUpdate(Map<String, dynamic> data) {
    return postJson('/hfl/update', data);
  }

  /// 推送推薦結果
  Future<Map<String, dynamic>> pushRecommendation(Map<String, dynamic> data) {
    return postJson('/api/push-recommendation', data);
  }
}
