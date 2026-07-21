import 'package:flutter/material.dart';
import '../../../shared/widgets/app_state_views.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
        children: [
          Text('月曆', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('每天的花費，一眼就知道', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 22),
          Card(
            child: CalendarDatePicker(
              initialDate: today,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              onDateChanged: (_) {},
            ),
          ),
          const SizedBox(height: 24),
          Text('當日紀錄', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          const AppEmptyView(title: '這天沒有紀錄', message: '選擇其他日期，或新增一筆交易。'),
        ],
      ),
    );
  }
}
