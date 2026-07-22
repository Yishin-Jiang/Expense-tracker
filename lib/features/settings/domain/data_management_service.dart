import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/taipei_time.dart';
import 'data_file_gateway.dart';

class DataSummary {
  const DataSummary({
    required this.transactionCount,
    required this.categoryCount,
    required this.subscriptionCount,
  });

  final int transactionCount;
  final int categoryCount;
  final int subscriptionCount;
}

class RestoreSummary extends DataSummary {
  const RestoreSummary({
    required super.transactionCount,
    required super.categoryCount,
    required super.subscriptionCount,
  });
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DataManagementService {
  const DataManagementService(this._database, this._fileGateway);

  static const _backupFormat = 'accounting_app_backup';
  static const _backupVersion = 1;

  final AppDatabase _database;
  final DataFileGateway _fileGateway;

  Future<DataSummary> loadSummary() async {
    final results = await Future.wait([
      (_database.select(
        _database.transactions,
      )..where((row) => row.deletedAt.isNull())).get(),
      _database.select(_database.categories).get(),
      _database.select(_database.subscriptions).get(),
    ]);
    return DataSummary(
      transactionCount: results[0].length,
      categoryCount: results[1].length,
      subscriptionCount: results[2].length,
    );
  }

  Future<ExportedDataFile> buildTransactionsCsv() async {
    final transactions =
        await (_database.select(_database.transactions)
              ..where((row) => row.deletedAt.isNull())
              ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]))
            .get();
    final categories = await _database.select(_database.categories).get();
    final channels = await _database.select(_database.channels).get();
    final categoryById = {for (final item in categories) item.id: item};
    final channelById = {for (final item in channels) item.id: item};

    final rows = <List<Object?>>[
      const ['編號', '日期', '類型', '金額', '類別', '父類別', '購物管道', '備註', '來源'],
      for (final transaction in transactions)
        () {
          final category = categoryById[transaction.categoryId];
          final parent = category?.parentId == null
              ? null
              : categoryById[category!.parentId!];
          return <Object?>[
            transaction.id,
            _formatDateTime(toTaipeiTime(transaction.occurredAt)),
            transaction.type == 'expense' ? '支出' : '收入',
            transaction.amount,
            category?.name ?? '',
            parent?.name ?? '',
            transaction.channelId == null
                ? ''
                : channelById[transaction.channelId]?.name ?? '',
            transaction.note ?? '',
            transaction.source == 'subscription' ? '訂閱' : '手動',
          ];
        }(),
    ];
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    final file = ExportedDataFile(
      name: 'accounting_transactions_${_fileStamp(DateTime.now())}.csv',
      mimeType: 'text/csv',
      bytes: Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]),
    );
    return file;
  }

  Future<void> exportTransactionsCsv() async {
    await _fileGateway.share(await buildTransactionsCsv());
  }

  Future<ExportedDataFile> buildBackup() async {
    final categories = await _database.select(_database.categories).get();
    final channels = await _database.select(_database.channels).get();
    final subscriptions = await _database.select(_database.subscriptions).get();
    final transactions = await _database.select(_database.transactions).get();
    final document = <String, Object?>{
      'format': _backupFormat,
      'version': _backupVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'databaseSchemaVersion': _database.schemaVersion,
      'data': {
        'categories': categories.map((item) => item.toJson()).toList(),
        'channels': channels.map((item) => item.toJson()).toList(),
        'subscriptions': subscriptions.map((item) => item.toJson()).toList(),
        'transactions': transactions.map((item) => item.toJson()).toList(),
      },
    };
    final contents = const JsonEncoder.withIndent('  ').convert(document);
    return ExportedDataFile(
      name: 'accounting_backup_${_fileStamp(DateTime.now())}.json',
      mimeType: 'application/json',
      bytes: Uint8List.fromList(utf8.encode(contents)),
    );
  }

  Future<void> exportBackup() async {
    await _fileGateway.share(await buildBackup());
  }

  Future<RestoreSummary?> pickAndRestoreBackup() async {
    final bytes = await _fileGateway.pickBackup();
    if (bytes == null) return null;
    return restoreBackup(bytes);
  }

  Future<RestoreSummary> restoreBackup(Uint8List bytes) async {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['format'] != _backupFormat ||
          decoded['version'] != _backupVersion) {
        throw const BackupFormatException('這不是支援的記帳 App 備份檔。');
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw const BackupFormatException('備份檔缺少資料內容。');
      }

      final categories = _decodeList(
        data,
        'categories',
        CategoryEntry.fromJson,
      );
      final channels = _decodeList(data, 'channels', ChannelEntry.fromJson);
      final subscriptions = _decodeList(
        data,
        'subscriptions',
        SubscriptionEntry.fromJson,
      );
      final transactions = _decodeList(
        data,
        'transactions',
        TransactionEntry.fromJson,
      );
      _validateBackup(categories, channels, subscriptions, transactions);
      await _database.replaceAllData(
        categories: categories,
        channels: channels,
        subscriptions: subscriptions,
        transactions: transactions,
      );
      return RestoreSummary(
        transactionCount: transactions
            .where((item) => item.deletedAt == null)
            .length,
        categoryCount: categories.length,
        subscriptionCount: subscriptions.length,
      );
    } on BackupFormatException {
      rethrow;
    } on FormatException catch (error) {
      throw BackupFormatException('備份檔格式錯誤：${error.message}');
    } catch (error) {
      throw BackupFormatException('無法讀取備份檔：$error');
    }
  }

  Future<void> clearAllData() => _database.clearAllDataAndRestoreDefaults();

  static List<T> _decodeList<T>(
    Map<String, dynamic> data,
    String key,
    T Function(Map<String, dynamic>) decode,
  ) {
    final raw = data[key];
    if (raw is! List) {
      throw BackupFormatException('備份檔缺少 $key。');
    }
    return raw.map((item) {
      if (item is! Map<String, dynamic>) {
        throw BackupFormatException('$key 包含無效資料。');
      }
      return decode(item);
    }).toList();
  }

  static void _validateBackup(
    List<CategoryEntry> categories,
    List<ChannelEntry> channels,
    List<SubscriptionEntry> subscriptions,
    List<TransactionEntry> transactions,
  ) {
    _validateBackupMetadata(categories, channels);
    final categoryIds = _uniqueIds(categories.map((item) => item.id), '類別');
    final channelIds = _uniqueIds(channels.map((item) => item.id), '購物管道');
    _uniqueIds(subscriptions.map((item) => item.id), '訂閱');
    _uniqueIds(transactions.map((item) => item.id), '交易');
    if (channels.map((item) => item.code).toSet().length != channels.length) {
      throw const BackupFormatException('購物管道代碼重複。');
    }

    final categoryById = {for (final item in categories) item.id: item};
    for (final category in categories) {
      if (!const {'expense', 'income', 'both'}.contains(category.type)) {
        throw const BackupFormatException('類別包含不支援的收支類型。');
      }
      final parentId = category.parentId;
      if (parentId == null) continue;
      if (parentId == category.id || !categoryIds.contains(parentId)) {
        throw const BackupFormatException('類別的父類別關聯無效。');
      }
      if (categoryById[parentId]?.parentId != null) {
        throw const BackupFormatException('備份包含超過兩層的類別。');
      }
    }
    for (final transaction in transactions) {
      if (!categoryIds.contains(transaction.categoryId) ||
          (transaction.channelId != null &&
              !channelIds.contains(transaction.channelId)) ||
          !const {'expense', 'income'}.contains(transaction.type) ||
          !const {'manual', 'subscription'}.contains(transaction.source) ||
          transaction.amount <= 0) {
        throw const BackupFormatException('交易資料或關聯無效。');
      }
      final category = categoryById[transaction.categoryId]!;
      if ((transaction.note?.length ?? 0) > 500 ||
          (category.type != 'both' && category.type != transaction.type)) {
        throw const BackupFormatException('交易與類別的內容不一致。');
      }
    }
    for (final subscription in subscriptions) {
      if (!categoryIds.contains(subscription.categoryId) ||
          (subscription.channelId != null &&
              !channelIds.contains(subscription.channelId)) ||
          !const {
            'monthly',
            'quarterly',
            'yearly',
          }.contains(subscription.billingCycle) ||
          subscription.amount <= 0 ||
          subscription.billingDay < 1 ||
          subscription.billingDay > 31) {
        throw const BackupFormatException('訂閱資料或關聯無效。');
      }
      final category = categoryById[subscription.categoryId]!;
      if (category.type == 'income' ||
          subscription.name.trim().isEmpty ||
          subscription.name.trim().length > 80 ||
          (subscription.note?.length ?? 0) > 500 ||
          subscription.nextBillingDate.isBefore(subscription.startDate) ||
          (subscription.endDate?.isBefore(subscription.startDate) ?? false)) {
        throw const BackupFormatException('訂閱內容或日期無效。');
      }
    }
  }

  static void _validateBackupMetadata(
    List<CategoryEntry> categories,
    List<ChannelEntry> channels,
  ) {
    final categoryById = {for (final item in categories) item.id: item};
    for (final channel in channels) {
      if (channel.code.trim().isEmpty ||
          channel.code.trim().length > 40 ||
          channel.name.trim().isEmpty ||
          channel.name.trim().length > 40) {
        throw const BackupFormatException('購物管道名稱或代碼無效。');
      }
    }
    for (final category in categories) {
      if (category.name.trim().isEmpty || category.name.trim().length > 40) {
        throw const BackupFormatException('類別名稱無效。');
      }
      if (category.color != null &&
          !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(category.color!)) {
        throw const BackupFormatException('類別顏色格式無效。');
      }
      final parent = category.parentId == null
          ? null
          : categoryById[category.parentId];
      if (parent == null) continue;
      if (parent.type != 'both' && parent.type != category.type) {
        throw const BackupFormatException('父子類別的收支類型不一致。');
      }
      if (category.isActive && !parent.isActive) {
        throw const BackupFormatException('啟用中的子類別不能隸屬於封存類別。');
      }
    }
  }

  static Set<int> _uniqueIds(Iterable<int> values, String label) {
    final list = values.toList();
    final ids = list.toSet();
    if (ids.length != list.length || ids.any((id) => id <= 0)) {
      throw BackupFormatException('$label ID 重複。');
    }
    return ids;
  }

  static String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  static String _formatDateTime(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  static String _fileStamp(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}_'
      '${value.hour.toString().padLeft(2, '0')}'
      '${value.minute.toString().padLeft(2, '0')}';
}
