import 'subscription.dart';

abstract interface class SubscriptionRepository {
  Stream<List<SubscriptionRecord>> watchSubscriptions();
  Future<SubscriptionRecord?> getSubscription(int id);
  Future<SubscriptionRecord> createSubscription(SubscriptionInput input);
  Future<SubscriptionRecord> updateSubscription(
    int id,
    SubscriptionInput input,
  );
  Future<void> setSubscriptionActive(int id, bool active);
  Future<int> processDueSubscriptions(DateTime today);
}
