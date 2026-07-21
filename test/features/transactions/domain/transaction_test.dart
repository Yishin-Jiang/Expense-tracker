import 'package:accounting_app/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid transaction input passes validation', () {
    final input = TransactionInput(
      categoryId: 1,
      type: TransactionType.expense,
      amount: 120,
      occurredAt: DateTime.utc(2026, 7, 21),
      note: ' 午餐 ',
    );
    expect(input.validate, returnsNormally);
  });

  test('invalid amount and category fail validation', () {
    final invalidAmount = TransactionInput(
      categoryId: 1,
      type: TransactionType.expense,
      amount: 0,
      occurredAt: DateTime.utc(2026, 7, 21),
    );
    final invalidCategory = TransactionInput(
      categoryId: 0,
      type: TransactionType.expense,
      amount: 100,
      occurredAt: DateTime.utc(2026, 7, 21),
    );
    expect(
      invalidAmount.validate,
      throwsA(isA<TransactionValidationException>()),
    );
    expect(
      invalidCategory.validate,
      throwsA(isA<TransactionValidationException>()),
    );
  });
}
