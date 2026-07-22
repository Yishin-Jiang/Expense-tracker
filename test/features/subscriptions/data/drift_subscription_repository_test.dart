import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/features/subscriptions/data/drift_subscription_repository.dart';
import 'package:accounting_app/features/subscriptions/domain/subscription.dart';
import 'package:accounting_app/features/subscriptions/presentation/providers/subscription_providers.dart';
import 'package:accounting_app/features/transactions/domain/transaction.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftSubscriptionRepository repository;
  late int lunchCategoryId;
  late int onlineChannelId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftSubscriptionRepository(database);
    await database.customSelect('SELECT 1').get();
    final categories = await database.select(database.categories).get();
    final channels = await database.select(database.channels).get();
    lunchCategoryId = categories.singleWhere((item) => item.name == '午餐').id;
    onlineChannelId = channels.singleWhere((item) => item.code == 'online').id;
  });

  tearDown(() => database.close());

  test('creates, updates, archives, and restores a subscription', () async {
    final created = await repository.createSubscription(
      SubscriptionInput(
        categoryId: lunchCategoryId,
        channelId: onlineChannelId,
        name: 'Spotify',
        amount: 199,
        billingCycle: BillingCycle.monthly,
        startDate: DateTime(2026, 7, 1),
        nextBillingDate: DateTime(2026, 8, 1),
        autoCreateTransaction: false,
      ),
    );
    expect(created.name, 'Spotify');
    expect(created.monthlyEstimate, 199);
    expect(created.annualEstimate, 2388);

    final updated = await repository.updateSubscription(
      created.id,
      SubscriptionInput(
        categoryId: lunchCategoryId,
        channelId: onlineChannelId,
        name: 'Spotify 學生方案',
        amount: 99,
        billingCycle: BillingCycle.monthly,
        startDate: DateTime(2026, 7, 1),
        nextBillingDate: DateTime(2026, 8, 1),
        autoCreateTransaction: false,
        note: '學生優惠',
      ),
    );
    expect(updated.name, 'Spotify 學生方案');
    expect(updated.note, '學生優惠');

    await repository.setSubscriptionActive(created.id, false);
    expect((await repository.getSubscription(created.id))?.isActive, isFalse);
    await repository.setSubscriptionActive(created.id, true);
    expect((await repository.getSubscription(created.id))?.isActive, isTrue);
  });

  test(
    'due auto subscription creates transactions once and advances date',
    () async {
      final created = await repository.createSubscription(
        SubscriptionInput(
          categoryId: lunchCategoryId,
          channelId: onlineChannelId,
          name: 'AI 服務',
          amount: 600,
          billingCycle: BillingCycle.monthly,
          startDate: DateTime(2026, 5, 31),
          nextBillingDate: DateTime(2026, 5, 31),
          autoCreateTransaction: true,
        ),
      );

      final processed = await Future.wait([
        repository.processDueSubscriptions(DateTime(2026, 7, 22)),
        repository.processDueSubscriptions(DateTime(2026, 7, 22)),
      ]);
      expect(processed.fold<int>(0, (sum, value) => sum + value), 2);
      final transactions = await database.select(database.transactions).get();
      expect(transactions, hasLength(2));
      expect(transactions.every((item) => item.amount == 600), isTrue);
      expect(
        transactions.every(
          (item) => item.source == TransactionSource.subscription.name,
        ),
        isTrue,
      );
      expect(transactions.every((item) => item.note == 'AI 服務 自動扣款'), isTrue);
      expect(
        (await repository.getSubscription(created.id))?.nextBillingDate,
        DateTime(2026, 7, 31),
      );

      expect(
        await repository.processDueSubscriptions(DateTime(2026, 7, 22)),
        0,
      );
      expect(await database.select(database.transactions).get(), hasLength(2));
    },
  );

  test('summary normalizes monthly quarterly and yearly costs', () async {
    final items = [
      _subscription(id: 1, amount: 120, cycle: BillingCycle.monthly),
      _subscription(id: 2, amount: 300, cycle: BillingCycle.quarterly),
      _subscription(id: 3, amount: 1200, cycle: BillingCycle.yearly),
    ];
    final summary = SubscriptionSummary.from(items, DateTime(2026, 7, 22));

    expect(summary.activeCount, 3);
    expect(summary.monthlyEstimate, 320);
    expect(summary.annualEstimate, 3840);
    expect(summary.upcoming, hasLength(3));
  });

  test('billing date preserves day 31 after short months', () {
    final february = nextBillingDate(
      DateTime(2026, 1, 31),
      BillingCycle.monthly,
      billingDay: 31,
    );
    final march = nextBillingDate(
      february,
      BillingCycle.monthly,
      billingDay: 31,
    );
    expect(february, DateTime(2026, 2, 28));
    expect(march, DateTime(2026, 3, 31));
  });
}

SubscriptionRecord _subscription({
  required int id,
  required int amount,
  required BillingCycle cycle,
}) => SubscriptionRecord(
  id: id,
  categoryId: 1,
  name: '訂閱 $id',
  amount: amount,
  billingCycle: cycle,
  billingDay: 25,
  startDate: DateTime(2026, 1),
  nextBillingDate: DateTime(2026, 7, 25),
  isActive: true,
  autoCreateTransaction: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
