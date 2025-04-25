import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:travel/spot_detail_page.dart'; // ⭐記得import

class AIRecommendResultPage extends StatefulWidget {
  final String? city;
  final double? budget;
  final String? transport;
  final List<String>? types;

  const AIRecommendResultPage({
    super.key,
    this.city,
    this.budget,
    this.transport,
    this.types,
  });

  @override
  State<AIRecommendResultPage> createState() => _AIRecommendResultPageState();
}

class _AIRecommendResultPageState extends State<AIRecommendResultPage> {
  List<Map<String, dynamic>> recommendedSpots = [];
  final Set<String> favoriteSpots = {}; // ✅收藏列表

  @override
  void initState() {
    super.initState();
    _loadSpotData();
  }

  Future<void> _loadSpotData() async {
    final rawData = await rootBundle.loadString('assets/data/ScenicSpot.csv');
    List<List<dynamic>> csvTable = const CsvToListConverter().convert(rawData, eol: '\n');

    // 取表頭
    final headers = csvTable.first.map((e) => e.toString()).toList();

    final List<Map<String, dynamic>> spots = [];

    for (var row in csvTable.skip(1)) {
      final spot = Map<String, dynamic>.fromIterables(
        headers,
        row.map((e) => e.toString()),
      );

      spots.add({
        'name': spot['名稱'] ?? '',
        'type': spot['類型'] ?? '',
        'location': spot['地點'] ?? '',
        'imageUrl': spot['圖片網址'] ?? '',
        'rating': double.tryParse(spot['評分'] ?? '4.5') ?? 4.5,
        'description': spot['簡介'] ?? '',
      });
    }

    setState(() {
      recommendedSpots = spots;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI推薦結果'),
      ),
      body: recommendedSpots.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 🔥 推薦條件簡述
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('出發地：${widget.city ?? "未指定"}'),
                        Text('預算：${widget.budget?.round() ?? 0} 元'),
                        Text('交通方式：${widget.transport ?? "不限"}'),
                        Text('旅遊類型：${widget.types?.join(', ') ?? "不限"}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🔥 推薦行程清單
                  Expanded(
                    child: ListView.builder(
                      itemCount: recommendedSpots.length,
                      itemBuilder: (context, index) {
                        final spot = recommendedSpots[index];
                        final isFavorite = favoriteSpots.contains(spot['name']);

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                spot['imageUrl'],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey,
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              ),
                            ),
                            title: Text(spot['name']),
                            subtitle: Row(
                              children: [
                                ...List.generate(5, (i) {
                                  final rating = spot['rating'] ?? 0.0;
                                  return Icon(
                                    i < rating.round()
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 18,
                                    color: Colors.amber,
                                  );
                                }),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.red : Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (isFavorite) {
                                    favoriteSpots.remove(spot['name']);
                                  } else {
                                    favoriteSpots.add(spot['name']);
                                  }
                                });
                              },
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SpotDetailPage(spot: spot),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 🔥 重新推薦按鈕
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // 回到條件設定頁
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新推薦'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
