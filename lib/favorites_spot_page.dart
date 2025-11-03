import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

// ===== 全站統一：奶茶文青風色票 =====
const kBgCream     = Color(0xFFFAF3E0); // 背景：淡奶茶米色
const kCardBase    = Color(0xFFEAD7B7); // 卡片底：奶茶棕
const kPressedTint = Color(0xFFD6C2A1); // 按下/hover
const kTextDark    = Color(0xFF4E342E); // 文字：深棕
const kAccent      = Color(0xFFB48A60); // 主色：拿鐵咖啡

class FavoritesSpotPage extends StatefulWidget {
  final bool isEmbedded;
  const FavoritesSpotPage({super.key, this.isEmbedded = false});

  @override
  State<FavoritesSpotPage> createState() => _FavoritesSpotPageState();
}

class _FavoritesSpotPageState extends State<FavoritesSpotPage> {
  Map<String, List<Map<String, String>>> cityGroupedSpots = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorite_spots') ?? [];
    final spots = favList.map((e) => Map<String, String>.from(jsonDecode(e))).toList();

    // 根據 Region 分組
    final Map<String, List<Map<String, String>>> grouped = {};
    for (var spot in spots) {
      final city = (spot['Region'] ?? '其他').trim().isEmpty ? '其他' : (spot['Region']!);
      grouped.putIfAbsent(city, () => []);
      grouped[city]!.add(spot);
    }

    // 排序
    final sortedKeys = grouped.keys.toList()..sort();
    final Map<String, List<Map<String, String>>> sorted = {};
    for (final k in sortedKeys) {
      final list = grouped[k]!..sort((a, b) => (a['Name'] ?? '').compareTo(b['Name'] ?? ''));
      sorted[k] = list!;
    }

    setState(() {
      cityGroupedSpots = sorted;
      _loading = false;
    });
  }

  // ====== Utils ======
  String _firstNonEmpty(Map<String, String> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  String? _tryGetImageUrl(Map<String, String> spot) {
    final url = _firstNonEmpty(spot, ['Picture', 'Photo', 'Image', 'PicUrl', 'Picture1', 'imageUrl', 'image']);
    if (url.isEmpty) return null;
    // 有些 CSV 可能帶多張以逗號分隔，取第一張
    return url.split(',').first.trim();
  }

  double? _toDoubleOrNull(String? s) {
    if (s == null) return null;
    return double.tryParse(s);
    // 有些資料會是 "25.0" 或 "25"，double.tryParse 都能處理
  }

  (double lat, double lng)? _getLatLng(Map<String, String> spot) {
    // 優先 lat/lng，其次 Py/Px（政府開放資料常用 Py=lat, Px=lng）
    final lat = _toDoubleOrNull(_firstNonEmpty(spot, ['lat', 'Lat', 'latitude', 'Latitude', 'Py']));
    final lng = _toDoubleOrNull(_firstNonEmpty(spot, ['lng', 'Lng', 'long', 'Long', 'longitude', 'Longitude', 'Px']));
    if (lat != null && lng != null) return (lat, lng);
    return null;
  }

  Future<void> _launchUrl(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kPressedTint,
          content: const Text('無法開啟連結', style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  // 改：資訊只讀本地資料（不上網）
  Future<void> _openInfo(Map<String, String> spot) async {
    _showInfoDialog(spot);
  }

  // 顯示本地資訊對話框
  void _showInfoDialog(Map<String, String> spot) {
    final name   = _firstNonEmpty(spot, ['Name','name']);
    final city   = _firstNonEmpty(spot, ['Region','City','city']);
    final addr   = _firstNonEmpty(spot, ['Add','Address','address']);
    final open   = _firstNonEmpty(spot, ['Opentime','OpenTime','OpeningHours','營業時間']);
    final tel    = _firstNonEmpty(spot, ['Tel','TEL','Phone','電話']);
    final ticket = _firstNonEmpty(spot, ['Ticketinfo','Ticket','票價','收費']);
    final desc   = _firstNonEmpty(spot, [
      'Toldescribe','Description','DescriptionDetail','Summary','Intro','intro','content','描述','簡介'
    ]);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          decoration: BoxDecoration(color: kBgCream, borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.fromLTRB(16,16,16,12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.isNotEmpty ? name : '景點資訊',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kTextDark, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (city.isNotEmpty || addr.isNotEmpty || open.isNotEmpty || tel.isNotEmpty || ticket.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.6), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    [
                      if (city.isNotEmpty || addr.isNotEmpty) '📍 ${[city, addr].where((e)=>e.isNotEmpty).join(" · ")}',
                      if (open.isNotEmpty)   '🕒 $open',
                      if (tel.isNotEmpty)    '☎️ $tel',
                      if (ticket.isNotEmpty) '💵 $ticket',
                    ].join('\n'),
                    style: const TextStyle(color: kTextDark, height: 1.4),
                  ),
                ),
              if (desc.isNotEmpty) const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.6), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      desc.isNotEmpty ? desc : '尚無介紹內容',
                      style: const TextStyle(color: kTextDark, height: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('關閉', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Future<void> _openNavigation(Map<String, String> spot) async {
    final coords = _getLatLng(spot);
    if (coords != null) {
      final (lat, lng) = coords;
      final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
      await _launchUrl(uri);
      return;
    }
    final addr = _firstNonEmpty(spot, ['Add', 'Address', 'address']);
    final name = _firstNonEmpty(spot, ['Name', 'name']);
    final q = (addr.isNotEmpty ? addr : name).trim();
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(q)}&travelmode=driving');
    await _launchUrl(uri);
  }

  void _showSpotSheet(Map<String, String> spot) {
    final imageUrl = _tryGetImageUrl(spot);
    final name = _firstNonEmpty(spot, ['Name', 'name']);
    final addr = _firstNonEmpty(spot, ['Add', 'Address', 'address']);
    final city = _firstNonEmpty(spot, ['Region', 'City', 'city']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: kBgCream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: kPressedTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                // 圖片
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16/9,
                    child: imageUrl == null
                        ? Container(
                            color: kCardBase,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_not_supported_outlined, color: kTextDark),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: kCardBase,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined, color: kTextDark),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                // 標題與地點
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isNotEmpty ? name : '無名稱',
                            style: const TextStyle(
                              color: kTextDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (city.isNotEmpty || addr.isNotEmpty)
                            Text(
                              [city, addr].where((e) => e.isNotEmpty).join(' · '),
                              style: const TextStyle(color: kTextDark, height: 1.3),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 兩個按鈕：資訊、導航
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openInfo(spot),
                        icon: const Icon(Icons.info_outline, color: Colors.white),
                        label: const Text('資訊', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPressedTint,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openNavigation(spot),
                        icon: const Icon(Icons.navigation_outlined, color: Colors.white),
                        label: const Text('導航', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(kAccent),
        ),
      );
    }
    if (cityGroupedSpots.isEmpty) {
      return const _EmptyState();
    }

    return RefreshIndicator(
      color: kAccent,
      onRefresh: _loadFavorites,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: cityGroupedSpots.entries.map((entry) {
          final city = entry.key;
          final spots = entry.value;

          return Card(
            color: kCardBase,
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Theme(
              data: theme.copyWith(
                dividerColor: Colors.transparent,
                splashColor: kPressedTint.withOpacity(.25),
                highlightColor: kPressedTint.withOpacity(.15),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                collapsedIconColor: kTextDark,
                iconColor: kTextDark,
                title: Text(
                  city,
                  style: const TextStyle(
                    color: kTextDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                children: spots.map((spot) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.place_outlined, color: kTextDark),
                      title: Text(
                        spot['Name'] ?? '無名稱',
                        style: const TextStyle(
                          color: kTextDark,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: (spot['Add']?.isNotEmpty ?? false)
                          ? Text(
                              spot['Add']!,
                              style: const TextStyle(color: kTextDark),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          : const Text('無地址', style: TextStyle(color: kTextDark)),
                      trailing: const Icon(Icons.chevron_right, color: kTextDark),
                      onTap: () => _showSpotSheet(spot), // 點擊開下方資訊視窗
                      onLongPress: () => _openInfo(spot), // 長按直接開本地資訊 Dialog（可選）
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    // 若嵌入在其它頁面的 Tab 內，就不要再包一層 Scaffold/AppBar
    if (widget.isEmbedded) {
      return _buildBody(context);
    }

    // 獨立頁面時維持原本的 Scaffold + AppBar
    return Scaffold(
      backgroundColor: kBgCream,
      appBar: AppBar(
        backgroundColor: kBgCream,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '收藏景點',
          style: TextStyle(color: kTextDark, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: kTextDark),
      ),
      body: _buildBody(context),
    );
  }

}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 72, color: kPressedTint),
            SizedBox(height: 12),
            Text(
              '尚無收藏景點',
              style: TextStyle(
                color: kTextDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '在探索或行程頁面點擊「收藏」即可在這裡快速查看。',
              style: TextStyle(color: kTextDark, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
