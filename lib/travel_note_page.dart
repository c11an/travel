import 'package:flutter/material.dart';

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

class _TravelNotePageState extends State<TravelNotePage> with TickerProviderStateMixin {
  late List<List<TextEditingController>> noteControllersPerDay;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.allDailySpots.length, vsync: this);
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
        widget.allDailySpots[day][i]['note'] = noteControllersPerDay[day][i].text;
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
      return const Center(child: Text("當日無景點"));
    }

    return ListView.builder(
      itemCount: spots.length,
      itemBuilder: (context, index) {
        final spot = spots[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text(spot['Name'] ?? '無名稱'),
            subtitle: widget.readOnly
                ? Text(spot['note'] ?? '尚未撰寫心得')
                : TextField(
                    controller: controllers[index],
                    decoration: const InputDecoration(
                      hintText: '撰寫心得...',
                    ),
                    maxLines: null,
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("撰寫旅遊心得"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: List.generate(widget.allDailySpots.length, (i) => Tab(text: 'Day ${i + 1}')),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(widget.allDailySpots.length, (i) => _buildDayContent(i)),
      ),
      bottomNavigationBar: widget.readOnly
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: _saveNotes,
                icon: const Icon(Icons.save),
                label: const Text("儲存心得"),
              ),
            ),
    );
  }
}
