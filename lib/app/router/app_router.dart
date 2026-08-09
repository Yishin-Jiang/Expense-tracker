import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../../features/analysis/presentation/analysis_page.dart';
import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/categories/presentation/category_form_page.dart';
import '../../features/categories/presentation/category_management_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/subscriptions/presentation/subscription_form_page.dart';
import '../../features/subscriptions/presentation/subscription_page.dart';
import '../../features/transactions/presentation/transaction_form_page.dart';
import '../../features/transactions/presentation/transaction_detail_page.dart';
import '../../features/transactions/presentation/transaction_history_page.dart';
import '../shell/app_shell.dart';

NoTransitionPage<void> _noTransitionPage(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

GoRouter createAppRouter({String initialLocation = '/home'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (_, state) => _noTransitionPage(state, const HomePage()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (_, state) =>
              _noTransitionPage(state, const SettingsPage()),
        ),
        GoRoute(
          path: '/calendar',
          pageBuilder: (_, state) =>
              _noTransitionPage(state, const CalendarPage()),
        ),
        GoRoute(
          path: '/categories',
          pageBuilder: (_, state) =>
              _noTransitionPage(state, const CategoryManagementPage()),
        ),
        GoRoute(
          path: '/categories/new',
          pageBuilder: (_, state) =>
              _noTransitionPage(state, const CategoryFormPage()),
        ),
        GoRoute(
          path: '/categories/:id/edit',
          pageBuilder: (_, state) => _noTransitionPage(
            state,
            CategoryFormPage(
              categoryId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ),
        GoRoute(
          path: '/transactions/history',
          pageBuilder: (_, state) =>
              _noTransitionPage(state, const TransactionHistoryPage()),
        ),
        GoRoute(
          path: '/transactions/new',
          pageBuilder: (_, state) {
            final date = state.uri.queryParameters['date'];
            return _noTransitionPage(
              state,
              TransactionFormPage(
                presetCategoryId: int.tryParse(
                  state.uri.queryParameters['categoryId'] ?? '',
                ),
                presetDate: date == null ? null : DateTime.tryParse(date),
              ),
            );
          },
        ),
        GoRoute(
          path: '/transactions/:id',
          pageBuilder: (_, state) => _noTransitionPage(
            state,
            TransactionDetailPage(
              transactionId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ),
        GoRoute(
          path: '/transactions/:id/edit',
          pageBuilder: (_, state) => _noTransitionPage(
            state,
            TransactionFormPage(
              transactionId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ),
        GoRoute(
          path: '/analysis',
          pageBuilder: (_, state) =>
              _noTransitionPage(state, const AnalysisPage()),
        ),
        GoRoute(
          path: '/subscriptions',
          pageBuilder: (_, state) =>
              _noTransitionPage(state, const SubscriptionPage()),
        ),
        GoRoute(
          path: '/subscriptions/new',
          pageBuilder: (_, state) =>
              _noTransitionPage(state, const SubscriptionFormPage()),
        ),
        GoRoute(
          path: '/subscriptions/:id/edit',
          pageBuilder: (_, state) => _noTransitionPage(
            state,
            SubscriptionFormPage(
              subscriptionId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ),
      ],
    ),
  ],
);
