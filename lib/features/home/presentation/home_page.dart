import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_state_views.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      children: [
        Text('今天也要花得明白', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text('所有資料只會儲存在你的裝置中', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('本月支出', style: TextStyle(color: Color(0xFFD9F0E0))),
              SizedBox(height: 12),
              Text(
                'NT\$ 0',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 18),
              LinearProgressIndicator(
                value: 0,
                minHeight: 8,
                backgroundColor: Color(0xFF47806B),
                color: AppColors.warning,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('今天的紀錄', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        AppEmptyView(
          title: '還沒有記帳紀錄',
          message: '新增第一筆收入或支出，開始掌握自己的生活費。',
          actionLabel: '新增一筆',
          onAction: () => context.go('/transactions/new'),
        ),
      ],
    ),
  );
}
