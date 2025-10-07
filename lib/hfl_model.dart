// lib/hfl_model.dart
import 'dart:math';
import 'package:flutter/foundation.dart'; // ✅ for debugPrint

class Example {
  Example(this.x, this.y);
  final List<double> x; // 特徵
  final int y;          // 標籤: 喜歡=1 / 不喜歡=0
}

class LRModel {
  LRModel(int dim)
      : w = List.filled(dim, 0.0),
        b = 0.0;

  List<double> w;
  double b;

  double _dot(List<double> a, List<double> b) {
    double s = 0;
    for (var i = 0; i < a.length; i++) s += a[i] * b[i];
    return s;
  }

  double _sig(double z) => 1.0 / (1.0 + exp(-z));

  double predictScore(List<double> x) => _sig(_dot(w, x) + b);

  /// ✅ 加上詳細訓練過程輸出（可看到 Loss 是否收斂）
  void train(List<Example> data, {int epochs = 5, double lr = 0.05}) {
    if (data.isEmpty) {
      debugPrint("⚠️ [LRModel] 無訓練資料，跳過訓練。");
      return;
    }

    debugPrint("🚀 [LRModel] 開始訓練 (${data.length} 筆資料, ${w.length} 維特徵, $epochs epochs)");
    for (var e = 0; e < epochs; e++) {
      double totalLoss = 0.0;

      for (final ex in data) {
        final p = predictScore(ex.x); // 預測
        final err = p - ex.y;         // 誤差 (y∈{0,1})
        totalLoss += 0.5 * err * err; // MSE 損失

        for (var i = 0; i < w.length; i++) {
          w[i] -= lr * err * ex.x[i];
        }
        b -= lr * err;
      }

      final avgLoss = totalLoss / data.length;
      debugPrint("📉 [LRModel] Epoch $e 完成 - 平均 Loss: ${avgLoss.toStringAsFixed(6)}");
    }

    debugPrint("✅ [LRModel] 訓練結束，b=${b.toStringAsFixed(4)} w[0]=${w.first.toStringAsFixed(4)}");
  }

  Map<String, dynamic> toJson() => {"w": w, "b": b};

  void load(Map<String, dynamic> m) {
    final ww = (m["w"] as List).map((e) => (e as num).toDouble()).toList();
    w = ww;
    b = (m["b"] as num).toDouble();
    debugPrint("🧠 [LRModel] 已載入全域模型權重 (w.length=${w.length}, b=${b.toStringAsFixed(4)})");
  }
}
