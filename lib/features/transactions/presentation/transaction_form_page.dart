import 'package:flutter/material.dart';

class TransactionFormPage extends StatelessWidget {
  const TransactionFormPage({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      children: [
        Text('新增一筆', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          '交易表單會在階段 3 接上本機資料庫。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 28),
        const TextField(
          enabled: false,
          decoration: InputDecoration(labelText: '金額', hintText: 'NT\$ 0'),
        ),
        const SizedBox(height: 16),
        const TextField(
          enabled: false,
          decoration: InputDecoration(labelText: '類別'),
        ),
        const SizedBox(height: 16),
        const TextField(
          enabled: false,
          decoration: InputDecoration(labelText: '日期'),
        ),
        const SizedBox(height: 24),
        const FilledButton(onPressed: null, child: Text('資料庫完成後即可儲存')),
      ],
    ),
  );
}
