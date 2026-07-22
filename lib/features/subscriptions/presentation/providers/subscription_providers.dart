import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/utils/taipei_time.dart';
import '../../data/drift_subscription_repository.dart';
import '../../domain/subscription.dart';
import '../../domain/subscription_repository.dart';

final subscriptionTodayProvider = Provider<DateTime>(
  (_) => toTaipeiTime(DateTime.now()),
);

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => DriftSubscriptionRepository(ref.watch(databaseProvider)),
);

final subscriptionsProvider =
    StreamProvider.autoDispose<List<SubscriptionRecord>>(
      (ref) => ref.watch(subscriptionRepositoryProvider).watchSubscriptions(),
    );

final subscriptionByIdProvider = FutureProvider.autoDispose
    .family<SubscriptionRecord?, int>(
      (ref, id) =>
          ref.watch(subscriptionRepositoryProvider).getSubscription(id),
    );

final processDueSubscriptionsProvider = FutureProvider<int>((ref) {
  final today = ref.watch(subscriptionTodayProvider);
  return ref
      .watch(subscriptionRepositoryProvider)
      .processDueSubscriptions(today);
});

final subscriptionSummaryProvider = Provider<AsyncValue<SubscriptionSummary>>((
  ref,
) {
  final today = ref.watch(subscriptionTodayProvider);
  return ref
      .watch(subscriptionsProvider)
      .whenData((items) => SubscriptionSummary.from(items, today));
});

class SubscriptionSummary {
  const SubscriptionSummary({
    required this.activeCount,
    required this.monthlyEstimate,
    required this.annualEstimate,
    required this.upcoming,
  });

  final int activeCount;
  final int monthlyEstimate;
  final int annualEstimate;
  final List<SubscriptionRecord> upcoming;

  factory SubscriptionSummary.from(
    List<SubscriptionRecord> items,
    DateTime today,
  ) {
    final todayOnly = DateTime(today.year, today.month, today.day);
    final upcomingEnd = todayOnly.add(const Duration(days: 7));
    final active = items.where((item) => item.isActive).toList();
    final annual = active.fold<int>(
      0,
      (sum, item) => sum + item.annualEstimate,
    );
    final upcoming =
        active
            .where(
              (item) =>
                  !item.nextBillingDate.isBefore(todayOnly) &&
                  !item.nextBillingDate.isAfter(upcomingEnd),
            )
            .toList()
          ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    return SubscriptionSummary(
      activeCount: active.length,
      monthlyEstimate: (annual / 12).round(),
      annualEstimate: annual,
      upcoming: List.unmodifiable(upcoming),
    );
  }
}
