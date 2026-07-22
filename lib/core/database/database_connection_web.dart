import 'package:drift/drift.dart';

QueryExecutor openDatabaseConnection() {
  return LazyDatabase(() async {
    throw UnsupportedError(
      'Web database setup is scheduled for stage 2. '
      'sqlite3.wasm and drift_worker.dart.js are not connected yet.',
    );
  });
}
