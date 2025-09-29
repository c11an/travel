// lib/hfl_model.dart
import 'dart:math';

class Example {
  Example(this.x, this.y);
  final List<double> x; // 特徵
  final int y;          // 標籤: 喜歡=1 / 不喜歡=0
}

class LRModel {
  LRModel(int dim) : w = List.filled(dim, 0.0), b = 0.0;
  List<double> w;
  double b;

  double _dot(List<double> a, List<double> b) {
    double s = 0;
    for (var i = 0; i < a.length; i++) s += a[i] * b[i];
    return s;
  }

  double _sig(double z) => 1.0 / (1.0 + exp(-z));

  double predictScore(List<double> x) => _sig(_dot(w, x) + b);

  void train(List<Example> data, {int epochs = 5, double lr = 0.05}) {
    if (data.isEmpty) return;
    for (var e = 0; e < epochs; e++) {
      for (final ex in data) {
        final p = predictScore(ex.x);         // 預測
        final err = p - ex.y;                 // 誤差 (y∈{0,1})
        for (var i = 0; i < w.length; i++) {  // SGD
          w[i] -= lr * err * ex.x[i];
        }
        b -= lr * err;
      }
    }
  }

  Map<String, dynamic> toJson() => {"w": w, "b": b};
  void load(Map<String, dynamic> m) {
    final ww = (m["w"] as List).map((e) => (e as num).toDouble()).toList();
    w = ww; b = (m["b"] as num).toDouble();
  }
}
