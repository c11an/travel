import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

Future<List<Map<String, String>>> loadCsv(String path) async {
  final raw = await rootBundle.loadString(path);

  // 使用 CsvToListConverter 處理編碼與分行問題
  final rows = const CsvToListConverter(eol: '\n').convert(raw.trim());

  final headers = rows.first.map((e) => e.toString().trim()).toList();

  final data = rows.skip(1).map((row) {
    return Map<String, String>.fromIterables(
      headers,
      row.map((e) => e.toString().trim()),
    );
  }).toList();

  return data;
}
