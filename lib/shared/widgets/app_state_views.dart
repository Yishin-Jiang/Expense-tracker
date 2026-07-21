import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.message = '載入中…'});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(message, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({required this.message, this.onRetry, super.key});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: AppColors.expense, size: 40),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('再試一次')),
        ],
      ],
    ),
  );
}

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.primary,
            child: Icon(Icons.receipt_long_outlined),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
