import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:travel/spot_detail_page.dart'; // ⭐記得import

class AIRecommendResultPage extends StatefulWidget {
  final String? city;
  final double? budget;
  final String? transport;
  final List<String>? types;
  final List<Map<String, String>> spots;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? gptRecommendation;

  const AIRecommendResultPage({
    super.key,
    this.city,
    this.budget,
    this.transport,
    this.types,
    required this.spots,
    this.startDate,
    this.endDate,
    this.gptRecommendation,
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
    _loadRecommendedSpots();
  }

  void _loadRecommendedSpots() {
    setState(() {
      recommendedSpots = widget.spots.map((spot) {
        return {
          'name': spot['Name'] ?? '',
          'type': spot['Category'] ?? '',
          'location': spot['Region'] ?? '',
          'imageUrl': spot['Picture1'] ?? '',
          'rating': 4.5,
          'description': spot['Description'] ?? '沒有描述',
        };
      }).toList();
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
                  // 🔥 顯示 GPT 生成的推薦行程（如果有）
                  if (widget.gptRecommendation != null) ...[
                    Text(
                      '🔮 GPT 推薦行程',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.gptRecommendation!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

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
                              child: spot['imageUrl'] != null && spot['imageUrl']!.isNotEmpty
                                  ? Image.network(
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
                                    )
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey,
                                      child: const Icon(Icons.image),
                                    ),
                            ),
                            title: Text(spot['name']),
                            subtitle: Text(spot['location']),
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
