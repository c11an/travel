import 'dart:convert';
import 'dart:developer' as dev; // ← 新增：好看 log
import 'package:shared_preferences/shared_preferences.dart';
import 'hfl_model.dart';
import 'features.dart';
import 'api.dart';
import 'hfl_client.dart';

const _kModelKey = 'hfl_model_lr_v1';
//const _kTrainBatchSize = 20; // 收集幾筆回饋就訓練+上傳
const _kTrainBatchSize = 1;

class PersonalizationController {
  PersonalizationController() : _model = LRModel(FeatureBuilder.dim);

  LRModel _model;
  final List<Example> _buffer = [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kModelKey);
    if (s != null && s.isNotEmpty) {
      final m = jsonDecode(s) as Map<String, dynamic>;
      _model.load(m);
    }
    if (s != null) {
      dev.log('📂 [Init] 已載入模型: ${_model.w.take(3).toList()} ...', name: 'Personalization');
    } else {
      dev.log('📂 [Init] 沒有舊模型，初始化新權重', name: 'Personalization');
    }

  }

  List<Map<String, String>> reRankCandidates(
    List<Map<String, String>> spots, {
    required double budget,
    required List<String> typesPrefer,
    int hour = 10,
  }) {
    if (_model.w.length != FeatureBuilder.dim) {
      _model = LRModel(FeatureBuilder.dim);
    }
    final scored = <Map<String, String>, double>{};
    for (final s in spots) {
      final x = FeatureBuilder.fromSpot(s, budget: budget, hour: hour, typesPrefer: typesPrefer);
      scored[s] = _model.predictScore(x);
    }
    final list = spots.toList()
      ..sort((a, b) => (scored[b]!).compareTo(scored[a]!));
    return list;
  }

  void feedbackPositive(
    Map<String, String> spot, {
    required double budget,
    required List<String> typesPrefer,
    int hour = 10,
  }) {
    final x = FeatureBuilder.fromSpot(spot, budget: budget, hour: hour, typesPrefer: typesPrefer);
    _buffer.add(Example(x, 1));
  }

  void feedbackNegative(
    Map<String, String> spot, {
    required double budget,
    required List<String> typesPrefer,
    int hour = 10,
  }) {
    final x = FeatureBuilder.fromSpot(spot, budget: budget, hour: hour, typesPrefer: typesPrefer);
    _buffer.add(Example(x, 0));
  }

  /// 若累積到門檻就本機訓練並上傳（= 5 的訓練+HFL 更新）
  Future<void> maybeTrainAndUpload({
    required ApiClient api,
    required String uid,
    int round = 1,
  }) async {
    if (_buffer.length < _kTrainBatchSize) return;

    // 本機訓練
    _model.train(_buffer, epochs: 5, lr: 0.05);
    _buffer.clear();

    // 存一份在本機
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModelKey, jsonEncode(_model.toJson()));

    // 上傳到後端做 FedAvg，並用回傳的全域權重覆蓋（如有）
    final hfl = HFLClient(baseUrl: api.base, uid: uid);

    try {
      dev.log(
        '[HFL] pushUpdate start',
        name: 'Personalization',
        error: {
          'uid': uid,
          'round': round,
          'num_examples': _kTrainBatchSize,
          'w_len': _model.w.length,
        },
      );

      final res = await hfl.pushUpdate(_model, _kTrainBatchSize, round: round);

      // 有些實作會回 Map，有些回空（204/空字串），這裡做兼容處理
      if (res is Map<String, dynamic>) {
        dev.log('[HFL] pushUpdate ok (map)', name: 'Personalization', error: res);
        // 如果後端有提供新的全域權重，可在此載入（視你的 HFLClient 約定）
        final global = res['global'] as Map<String, dynamic>?;
        if (global != null) {
          _model.load(global);
          await prefs.setString(_kModelKey, jsonEncode(_model.toJson()));
        }
      } else if (res is String && res.isNotEmpty) {
        // 嘗試解析字串
        try {
          final m = jsonDecode(res);
          if (m is Map<String, dynamic>) {
            dev.log('[HFL] pushUpdate ok (string→map)', name: 'Personalization', error: m);
            final global = m['global'] as Map<String, dynamic>?;
            if (global != null) {
              _model.load(global);
              await prefs.setString(_kModelKey, jsonEncode(_model.toJson()));
            }
          } else {
            dev.log('[HFL] pushUpdate ok (string, non-map)', name: 'Personalization', error: res);
          }
        } catch (_) {
          dev.log('[HFL] pushUpdate ok (non-json string)', name: 'Personalization', error: res);
        }
      } else {
        // null 或非預期型別就當成功但記錄
        dev.log('[HFL] pushUpdate ok (null/unknown)', name: 'Personalization', error: res);
      }
    } on TypeError catch (e, st) {
      // 常見於：後端回空 → HFLClient 內部把 null 當 Map cast
      dev.log('[HFL] pushUpdate type error（多半是後端回空或非 JSON）', name: 'Personalization', error: e, stackTrace: st);
      // 不中斷流程；若你想讓 UI 知道可以在這裡發出非致命警告（例如 Toast）
      return;
    } catch (e, st) {
      // 其它錯誤才真的拋出，讓上層顯示錯誤
      dev.log('[HFL] pushUpdate failed', name: 'Personalization', error: e, stackTrace: st);
      throw Exception('HFL 上傳失敗：$e');
    }
  }

    /// 🧠 本地訓練（不上傳）版本，手動觸發訓練並印出 log
  Future<void> trainLocalOnly({int epochs = 5, double lr = 0.05}) async {
    if (_buffer.isEmpty) {
      dev.log('⚠️ [LocalTrain] buffer 為空，無需訓練', name: 'Personalization');
      return;
    }

    // 🧾 log buffer 狀態
    dev.log('🚀 [LocalTrain] start: data=${_buffer.length}, epochs=$epochs, lr=$lr',
        name: 'Personalization');

    // ✅ 本地訓練
    _model.train(_buffer, epochs: epochs, lr: lr);

    // 清除暫存 buffer
    _buffer.clear();

    // 🧠 儲存模型到 SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModelKey, jsonEncode(_model.toJson()));

    // ✅ 結束 log
    dev.log('✅ [LocalTrain] end: 已完成訓練並儲存至本機', name: 'Personalization');
  }

}
