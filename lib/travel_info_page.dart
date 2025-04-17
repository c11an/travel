import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'travel_day_page.dart';

class TravelInfoInputPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const TravelInfoInputPage({super.key, this.initialData});

  @override
  State<TravelInfoInputPage> createState() => _TravelInfoInputPageState();
}

class _TravelInfoInputPageState extends State<TravelInfoInputPage> {
  final TextEditingController _tripNameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  String _selectedTransport = '汽車';
  String _selectedTripType = '自訂';

  final List<String> _transportOptions = ['汽車', '機車', '步行', '大眾交通'];
  final List<String> _tripTypeOptions = ['自訂', '商務', '親子', '戶外', '文化'];

  bool get isEditing => widget.initialData != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      final data = widget.initialData!;
      _tripNameController.text = (data['trip_name'] ?? '') as String;
      _budgetController.text = (data['budget']?.toString() ?? '');
      _startDateController.text = (data['start_date'] ?? '') as String;
      _endDateController.text = (data['end_date'] ?? '') as String;
      _selectedTransport = (data['transport'] ?? '汽車') as String;
      _selectedTripType = (data['trip_type'] ?? '自訂') as String;
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  void _submit() {
    if (_tripNameController.text.isEmpty ||
        _budgetController.text.isEmpty ||
        _startDateController.text.isEmpty ||
        _endDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請填寫完整資訊')),
      );
      return;
    }

    final tripData = {
      'trip_name': _tripNameController.text,
      'budget': int.tryParse(_budgetController.text) ?? 0,
      'start_date': _startDateController.text,
      'end_date': _endDateController.text,
      'transport': _selectedTransport,
      'trip_type': _selectedTripType, // ✅ 加入 trip_type
    };

    if (isEditing) {
      Navigator.pop(context, tripData);
    } else {
      final startDate = DateFormat('yyyy-MM-dd').parse(tripData['start_date'] as String);
      final endDate = DateFormat('yyyy-MM-dd').parse(tripData['end_date'] as String);
      final tripName = tripData['trip_name'] as String;
      final transport = tripData['transport'] as String;
      final budget = tripData['budget'] as int;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TravelDayPage(
            tripName: tripName,
            startDate: startDate,
            endDate: endDate,
            budget: budget,
            transport: transport,
          ),
        ),
      ).then((finalResult) {
        if (finalResult != null && finalResult is Map<String, dynamic>) {
          finalResult['trip_type'] = _selectedTripType; // 👈 確保傳回結果也包含類型
          Navigator.pop(context, finalResult);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '編輯行程資訊' : '輸入行程資訊')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _tripNameController,
              decoration: const InputDecoration(
                labelText: '行程名稱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: '開始日期',
                      border: OutlineInputBorder(),
                    ),
                    onTap: () => _selectDate(_startDateController),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _endDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: '結束日期',
                      border: OutlineInputBorder(),
                    ),
                    onTap: () => _selectDate(_endDateController),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '預算（元）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTripType,
              items: _tripTypeOptions
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedTripType = value);
              },
              decoration: const InputDecoration(
                labelText: '行程類型',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTransport,
              items: _transportOptions
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedTransport = value);
                }
              },
              decoration: const InputDecoration(
                labelText: '預計交通方式',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(isEditing ? '儲存行程' : '下一步'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
