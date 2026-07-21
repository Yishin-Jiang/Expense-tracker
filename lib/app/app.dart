import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router/app_router.dart';

class AccountingApp extends StatelessWidget {
  const AccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '好好記帳',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
