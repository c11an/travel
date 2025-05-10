import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelNotePage extends StatefulWidget {
  final List<List<Map<String, String>>> dailySpots;
  final int dayIndex;
  final bool readOnly;

  const TravelNotePage({
    super.key,
    required this.dailySpots,
    required this.dayIndex,
    this.readOnly = false,
  });

  @override
  State<TravelNotePage> createState() => _TravelNotePageState();
}

class _TravelNotePageState extends State<TravelNotePage> {
  List<TextEditingController> noteControllers = [];

  void _initializeNoteControllers() {
    noteControllers = widget.dailySpots[widget.dayIndex]
        .map((spot) => TextEditingController(
            text: widget.readOnly ? (spot['note'] ?? '') : '', // ✅ 新增模式預設空白
          ))
      .toList();
  }

  @override
  void initState() {
    super.initState();
    _initializeNoteControllers();
  }

  void _saveNotes() async {
    for (int i = 0; i < widget.dailySpots[widget.dayIndex].length; i++) {
      widget.dailySpots[widget.dayIndex][i]['note'] = noteControllers[i].text;
    }
    // 保存到本地
    await _saveNotesToLocal();
    Navigator.pop(context, widget.dailySpots);
  }

  Future<void> _saveNotesToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final noteData = widget.dailySpots.map((day) {
      return day.map((spot) => jsonEncode(spot)).toList();
    }).toList();
    await prefs.setStringList('travel_notes_${widget.dayIndex}', noteData[widget.dayIndex]);
  }

  Future<void> _loadNotesFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final noteData = prefs.getStringList('travel_notes_${widget.dayIndex}');
    if (noteData != null) {
      setState(() {
        for (int i = 0; i < widget.dailySpots[widget.dayIndex].length; i++) {
          widget.dailySpots[widget.dayIndex][i]['note'] = jsonDecode(noteData[i])['note'] ?? '';
          noteControllers[i].text = widget.dailySpots[widget.dayIndex][i]['note'] ?? '';
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadNotesFromLocal();
  }

  @override
  void dispose() {
    for (var controller in noteControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Day ${widget.dayIndex + 1} - ${widget.readOnly ? '查看心得' : '新增心得'}"),
      ),
      body: ListView.builder(
        itemCount: widget.dailySpots[widget.dayIndex].length,
        itemBuilder: (context, index) {
          final spot = widget.dailySpots[widget.dayIndex][index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text(spot['Name'] ?? '無名稱'),
              subtitle: widget.readOnly
                  ? Text(spot['note'] ?? '尚未撰寫心得')
                  : TextField(
                      controller: noteControllers[index],
                      decoration: const InputDecoration(
                        hintText: '撰寫心得...',
                      ),
                      maxLines: null,
                    ),
            ),
          );
        },
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
