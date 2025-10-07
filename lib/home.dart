import 'package:flutter/material.dart';
import 'package:travel/ai_recommend_page.dart';
import 'package:travel/travel_form_page.dart';
import 'package:travel/travel_input_page.dart';
import 'package:travel/journal_page.dart';
import 'package:travel/profile_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _bgGray = Color(0xFFF5F5F5);
  static const _pillBlue = Color(0xFFB8DEFF); // 手稿標的淺藍
  static const _royalBlue = Color(0xFF283653); // 寶藍字色


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.transparent,
        elevation: 0,
        // 右上角「首頁/返回」區：這裡放一個 home 與 info
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.black87),
            onPressed: () {}, // 已在首頁，不做事
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            /// 顶部橢圓「AI 推薦」
            _AiRecommendPill(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AIRecommendPage()),
              ),
            ),

            const SizedBox(height: 24),

            /// 2x2 方塊
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, c) {
                    // 讓方塊在窄螢幕也不會擠壞
                    final maxWidth = c.maxWidth.clamp(320.0, 560.0);
                    final itemSize = (maxWidth - 32 /*左右padding*/ - 16 /*格間距總和*/) / 2;
                    return SizedBox(
                      width: maxWidth,
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          _SquareButton(
                            label: '我的行程',
                            imageAsset: 'assets/images/destination.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TravelInputPage()),
                            ),
                            size: itemSize,
                          ),
                          _SquareButton(
                            label: '搜尋',
                            imageAsset: 'assets/images/search.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TravelFormPage()),
                            ),
                            size: itemSize,
                          ),
                          _SquareButton(
                            label: '日誌',
                            imageAsset: 'assets/images/journey-1.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const JournalPage()),
                            ),
                            size: itemSize,
                          ),
                          _SquareButton(
                            label: '個人',
                            imageAsset: 'assets/images/person.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ProfilePage()),
                            ),
                            size: itemSize,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}



class _AiRecommendPill extends StatelessWidget {
  const _AiRecommendPill({required this.onTap});
  final VoidCallback onTap;

  static const _pillBlue = Color(0xFFB8DEFF);
  static const _royalBlue = Color(0xFF283653);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(2, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999), // 圓角按鈕
          child: Image.asset(
            'assets/images/AI.png',
            width: 120,     // 可自行調整大小
            height: 120,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.label,
    required this.onTap,
    required this.size,
    this.icon,              // 可選
    this.imageAsset, // ✅ 給預設色（或 Colors.blue）
    this.iconColor = Colors.white,
  });

  final String label;
  final VoidCallback onTap;
  final double size;
  final IconData? icon;
  final String? imageAsset;
  final Color iconColor; // ✅ 不再報錯（一定有值）
  @override
  Widget build(BuildContext context) {
    final double iconSize = size * 0.35;

    final Widget leading = (imageAsset != null)
        ? Image.asset(
            imageAsset!,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          )
        : Icon(icon, size: iconSize, color: iconColor);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(2, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: size * 0.16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

