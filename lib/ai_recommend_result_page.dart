import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 📋 推薦條件簡述
          Text('出發地：${widget.city ?? "未指定"}'),
          if (widget.startDate != null && widget.endDate != null)
            Text(
              '旅遊時間：${DateFormat('yyyy/MM/dd').format(widget.startDate!)} ~ ${DateFormat('yyyy/MM/dd').format(widget.endDate!)}',
            )
          else
            const Text('旅遊時間：未指定'),
          Text('預算：${widget.budget?.round() ?? 0} 元'),
          Text('交通方式：${widget.transport ?? "不限"}'),
          Text('旅遊類型：${widget.types?.join(', ') ?? "不限"}'),
          const SizedBox(height: 16),

          // 🔮 GPT 推薦行程
          if ((widget.gptRecommendation ?? '').trim().isNotEmpty) ...[
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _parseGptRecommendation(widget.gptRecommendation!),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 🧭 推薦景點清單
          if (recommendedSpots.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            )
          else
            ...recommendedSpots.map((spot) {
              final isFavorite = favoriteSpots.contains(spot['name']);
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: spot['imageUrl'] != null &&
                            spot['imageUrl']!.isNotEmpty
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
            }),

          const SizedBox(height: 16),

          // 🔁 重新推薦
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重新推薦'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}




  List<Widget> _parseGptRecommendation(String text) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('Day')) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(
          Text(
            line,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        );
      } else if (line.contains('：')) {
        final parts = line.split('：');
        if (parts.length == 2) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${parts[0]}：",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(parts[1])),
                ],
              ),
            ),
          );
        } else {
          widgets.add(Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(line),
          ));
        }
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: Text(line),
        ));
      }
    }

    return widgets;
  }

}
