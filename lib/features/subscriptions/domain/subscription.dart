enum BillingCycle { monthly, quarterly, yearly }

class SubscriptionRecord {
  const SubscriptionRecord({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.billingCycle,
    required this.billingDay,
    required this.startDate,
    required this.nextBillingDate,
    required this.isActive,
    required this.autoCreateTransaction,
    required this.createdAt,
    required this.updatedAt,
    this.channelId,
    this.endDate,
    this.note,
  });

  final int id;
  final int categoryId;
  final int? channelId;
  final String name;
  final int amount;
  final BillingCycle billingCycle;
  final int billingDay;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextBillingDate;
  final String? note;
  final bool isActive;
  final bool autoCreateTransaction;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get annualEstimate => switch (billingCycle) {
    BillingCycle.monthly => amount * 12,
    BillingCycle.quarterly => amount * 4,
    BillingCycle.yearly => amount,
  };

  double get monthlyEstimate => annualEstimate / 12;
}

class SubscriptionInput {
  const SubscriptionInput({
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.billingCycle,
    required this.startDate,
    required this.nextBillingDate,
    required this.autoCreateTransaction,
    this.channelId,
    this.endDate,
    this.note,
  });

  final int categoryId;
  final int? channelId;
  final String name;
  final int amount;
  final BillingCycle billingCycle;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextBillingDate;
  final String? note;
  final bool autoCreateTransaction;

  void validate() {
    if (categoryId <= 0) throw const FormatException('請選擇支出類別');
    if (channelId != null && channelId! <= 0) {
      throw const FormatException('購物管道無效');
    }
    if (name.trim().isEmpty) throw const FormatException('請輸入訂閱名稱');
    if (name.trim().length > 80) {
      throw const FormatException('訂閱名稱不能超過 80 個字元');
    }
    if (amount <= 0) throw const FormatException('金額必須大於 0');
    if (_dateOnly(nextBillingDate).isBefore(_dateOnly(startDate))) {
      throw const FormatException('下次扣款日不能早於開始日期');
    }
    if (endDate != null && _dateOnly(endDate!).isBefore(_dateOnly(startDate))) {
      throw const FormatException('結束日期不能早於開始日期');
    }
    if (note != null && note!.trim().length > 500) {
      throw const FormatException('備註不能超過 500 個字元');
    }
  }
}

DateTime nextBillingDate(
  DateTime current,
  BillingCycle cycle, {
  required int billingDay,
}) {
  final months = switch (cycle) {
    BillingCycle.monthly => 1,
    BillingCycle.quarterly => 3,
    BillingCycle.yearly => 12,
  };
  final target = DateTime(current.year, current.month + months);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(
    target.year,
    target.month,
    billingDay > lastDay ? lastDay : billingDay,
  );
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
