import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String googleApiKey = 'AIzaSyC1UdVpu5sEOvOrJCidr8YZPMWTgQKazjs'; // 改成你的

class DirectionsApiTest extends StatefulWidget {
  const DirectionsApiTest({super.key});

  @override
  State<DirectionsApiTest> createState() => _DirectionsApiTestState();
}

class _DirectionsApiTestState extends State<DirectionsApiTest> {
  String result = "尚未測試";

  Future<void> testDirections() async {
    final origin = '25.0330,121.5654'; // 台北101
    final destination = '25.0478,121.5319'; // 台北車站

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$destination&mode=driving&key=$googleApiKey',
    );

    final res = await http.get(url);

    if (res.statusCode != 200) {
      setState(() {
        result = '❌ API 回傳錯誤 (${res.statusCode})';
      });
      return;
    }

    final data = jsonDecode(res.body);
    if (data['routes'] != null && data['routes'].isNotEmpty) {
      setState(() {
        result = '✅ 成功取得路線，共 ${data['routes'].length} 筆';
      });
    } else {
      setState(() {
        result = '⚠️ 沒有找到路線或 API 回傳空資料';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("測試 Directions API")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(result, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: testDirections,
              child: const Text("測試 Directions API"),
            ),
          ],
        ),
      ),
    );
  }
}
