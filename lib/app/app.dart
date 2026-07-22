import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/subscriptions/presentation/providers/subscription_providers.dart';
import 'router/app_router.dart';

class AccountingApp extends ConsumerStatefulWidget {
  const AccountingApp({this.initialLocation = '/home', super.key});

  final String initialLocation;

  @override
  ConsumerState<AccountingApp> createState() => _AccountingAppState();
}

class _AccountingAppState extends ConsumerState<AccountingApp> {
  late final _router = createAppRouter(initialLocation: widget.initialLocation);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(processDueSubscriptionsProvider);
    return MaterialApp.router(
      title: '好好記帳',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
