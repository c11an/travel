// lib/features.dart
class FeatureBuilder {
  // 定義固定維度的特徵： [budget_norm, is_food, is_spot, morning, afternoon, evening, ...one-hot types...]
  static const _types = ['自然', '文化', '美食', '購物', '親子', '夜景'];
  static int dim = 2 + 3 + _types.length;

  static List<double> fromSpot(Map<String, String> spot, {
    required double budget,
    required int hour, // 9~19
    required List<String> typesPrefer, // 使用者偏好
  }) {
    final v = List<double>.filled(dim, 0.0);
    // 0: budget_norm（以一萬為基準）
    v[0] = (budget.clamp(0, 10000)) / 10000.0;
    // 1: is_food / is_spot
    final isFood = (spot['Type'] ?? '').contains('美食') ? 1.0 : 0.0;
    v[1] = isFood;
    // 2..4: 時段 one-hot
    v[2] = (hour < 12) ? 1.0 : 0.0;           // morning
    v[3] = (hour >= 12 && hour < 17) ? 1.0:0; // afternoon
    v[4] = (hour >= 17) ? 1.0 : 0.0;          // evening
    // 5.. : 景點類型 one-hot（若使用者偏好含此類型，可略微加權）
    for (var i = 0; i < _types.length; i++) {
      final hit = (spot['Category'] ?? '').contains(_types[i]) ? 1.0 : 0.0;
      final preferBoost = typesPrefer.contains(_types[i]) ? 0.3 : 0.0;
      v[5 + i] = hit + preferBoost;
    }
    return v;
  }
}
