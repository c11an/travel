import 'package:flutter/material.dart';

// ===== 全站統一：奶茶文青風色票 =====
const kBgCream     = Color(0xFFFAF3E0); // 背景：淡奶茶米色
const kCardBase    = Color(0xFFEAD7B7); // 卡片底：奶茶棕
const kPressedTint = Color(0xFFD6C2A1); // 按下/hover
const kTextDark    = Color(0xFF4E342E); // 文字：深棕
const kAccent      = Color(0xFFB48A60); // 主色：拿鐵咖啡

class TravelNotePage extends StatefulWidget {
  final List<List<Map<String, String>>> allDailySpots;
  final bool readOnly;

  const TravelNotePage({
    super.key,
    required this.allDailySpots,
    this.readOnly = false,
  });

  @override
  State<TravelNotePage> createState() => _TravelNotePageState();
}

class _TravelNotePageState extends State<TravelNotePage>
    with TickerProviderStateMixin {
  late List<List<TextEditingController>> noteControllersPerDay;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: widget.allDailySpots.length, vsync: this);
    _initializeControllers();
  }

  void _initializeControllers() {
    noteControllersPerDay = widget.allDailySpots.map((daySpots) {
      return daySpots
          .map((spot) => TextEditingController(text: spot['note'] ?? ''))
          .toList();
    }).toList();
  }

  void _saveNotes() {
    for (int day = 0; day < widget.allDailySpots.length; day++) {
      for (int i = 0; i < widget.allDailySpots[day].length; i++) {
        widget.allDailySpots[day][i]['note'] =
            noteControllersPerDay[day][i].text;
      }
    }
    Navigator.pop(context, widget.allDailySpots); // ✅ 傳回修改後資料
  }

  @override
  void dispose() {
    for (var controllers in noteControllersPerDay) {
      for (var controller in controllers) {
        controller.dispose();
      }
    }
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildDayContent(int dayIndex) {
    final spots = widget.allDailySpots[dayIndex];
    final controllers = noteControllersPerDay[dayIndex];

    if (spots.isEmpty) {
      return const Center(
        child: Text("當日無景點", style: TextStyle(color: kTextDark)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: spots.length,
      itemBuilder: (context, index) {
        final spot = spots[index];
        final hasNote = (spot['note']?.trim().isNotEmpty ?? false);

        return Card(
          color: kCardBase,
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 標題列
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        spot['Name'] ?? '無名稱',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kTextDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasNote ? kAccent : kPressedTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        hasNote ? "已撰寫" : "未撰寫",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),

                // 內容區
                widget.readOnly
                    ? Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          spot['note']?.trim().isNotEmpty == true
                              ? spot['note']!.trim()
                              : '尚未撰寫心得',
                          style: const TextStyle(
                            color: kTextDark,
                            height: 1.4,
                          ),
                        ),
                      )
                    : TextField(
                        controller: controllers[index],
                        style: const TextStyle(color: kTextDark),
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: '撰寫心得…',
                          hintStyle: const TextStyle(
                              color: kTextDark, fontWeight: FontWeight.w400),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.6),
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: kPressedTint.withOpacity(.6)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: kAccent, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgCream,
      appBar: AppBar(
        backgroundColor: kBgCream,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.readOnly ? "查看旅遊心得" : "撰寫旅遊心得",
          style: const TextStyle(
            color: kTextDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: kTextDark),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kCardBase,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: kTextDark,
                unselectedLabelColor: kTextDark,
                indicator: BoxDecoration(
                  color: kPressedTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: List.generate(
                  widget.allDailySpots.length,
                  (i) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Tab(text: 'Day ${i + 1}'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(
          widget.allDailySpots.length,
          (i) => _buildDayContent(i),
        ),
      ),
      bottomNavigationBar: widget.readOnly
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _saveNotes,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text(
                      "儲存心得",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
