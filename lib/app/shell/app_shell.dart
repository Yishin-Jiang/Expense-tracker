import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});
  final String location;
  final Widget child;

  static const locations = [
    '/home',
    '/calendar',
    '/transactions/new',
    '/analysis',
    '/subscriptions',
  ];

  @override
  Widget build(BuildContext context) {
    final found = location.startsWith('/transactions')
        ? 2
        : locations.indexWhere(location.startsWith);
    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: found < 0 ? 0 : found,
            onDestinationSelected: (index) => context.go(locations[index]),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: '首頁',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                label: '月曆',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline),
                label: '記帳',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                label: '分析',
              ),
              NavigationDestination(
                icon: Icon(Icons.autorenew_outlined),
                label: '訂閱',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
