import 'package:flutter/material.dart';
import 'package:travel/ai_recommend_page.dart';
import 'package:travel/travel_form_page.dart';
import 'package:travel/travel_input_page.dart';
import 'package:travel/journal_page.dart';
import 'package:travel/profile_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // ===== 方案B：奶油粉系配色 =====
  // === 文青風：奶茶米色系 ===
  static const _bgCream     = Color(0xFFFAF3E0); // 背景：淡奶茶米色
  static const _cardBase    = Color(0xFFEAD7B7); // 功能鍵底色：奶茶棕
  static const _pressedTint = Color(0xFFD6C2A1); // 按下/hover 顏色：更深一階
  static const _textDark    = Color(0xFF4E342E); // 字體顏色：深棕
  static const _accentCoral = Color(0xFFB48A60); // 主色點綴：拿鐵咖啡色


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCream,
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: _textDark),
            onPressed: () {}, // 已在首頁
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            /// 頂部橢圓「AI 推薦」
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
                    final maxWidth = c.maxWidth.clamp(320.0, 560.0);
                    final itemSize =
                        (maxWidth - 32 /*左右padding*/ - 16 /*格間距總和*/) / 2;
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
                              MaterialPageRoute(
                                  builder: (_) => const TravelInputPage()),
                            ),
                            size: itemSize,
                          ),
                          _SquareButton(
                            label: '搜尋',
                            imageAsset: 'assets/images/search.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TravelFormPage()),
                            ),
                            size: itemSize,
                          ),
                          _SquareButton(
                            label: '日誌',
                            imageAsset: 'assets/images/journey.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const JournalPage()),
                            ),
                            size: itemSize,
                          ),
                          _SquareButton(
                            label: '個人',
                            imageAsset: 'assets/images/person.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProfilePage()),
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

  // 直接使用 HomePage 裡的顏色
  static const _bg = HomePage._cardBase;
  static const _shadow = Colors.black12;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: HomePage._accentCoral.withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(color: _shadow, blurRadius: 8, offset: Offset(2, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Image.asset(
            'assets/images/AI-1.png',
            width: 200,
            height: 200,
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
    this.imageAsset,
    this.icon,
    this.iconColor = HomePage._textDark,
  });

  final String label;
  final VoidCallback onTap;
  final double size;
  final IconData? icon;
  final String? imageAsset;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final double iconSize = size * 0.7;

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
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      splashColor: HomePage._pressedTint.withOpacity(0.25),
      highlightColor: HomePage._pressedTint.withOpacity(0.18),
      child: Ink(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: HomePage._cardBase,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: HomePage._accentCoral.withOpacity(0.22),
            width: 1.2,
          ),
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
                fontSize: size * 0.1,
                fontWeight: FontWeight.w700,
                color: HomePage._textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
