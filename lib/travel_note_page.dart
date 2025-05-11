import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelNotePage extends StatefulWidget {
  final List<Map<String, String>> dailySpots;
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

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    noteControllers = widget.dailySpots
        .map((spot) => TextEditingController(text: spot['note'] ?? ''))
        .toList();
  }

  void _saveNotes() {
    for (int i = 0; i < widget.dailySpots.length; i++) {
      widget.dailySpots[i]['note'] = noteControllers[i].text;
    }
    Navigator.pop(context, widget.dailySpots); // ✅ 回傳已儲存的心得
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
        itemCount: widget.dailySpots.length,
        itemBuilder: (context, index) {
          final spot = widget.dailySpots[index];
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

