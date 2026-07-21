import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/transactions/presentation/transaction_form_page.dart';
import '../shell/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomePage()),
        GoRoute(path: '/calendar', builder: (_, _) => const CalendarPage()),
        GoRoute(
          path: '/transactions/new',
          builder: (_, _) => const TransactionFormPage(),
        ),
        GoRoute(
          path: '/analysis',
          builder: (_, _) => const ComingSoonPage(title: '分析'),
        ),
        GoRoute(
          path: '/subscriptions',
          builder: (_, _) => const ComingSoonPage(title: '訂閱'),
        ),
      ],
    ),
  ],
);

class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({required this.title, super.key});
  final String title;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('此功能將在核心記帳完成後加入。', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}
