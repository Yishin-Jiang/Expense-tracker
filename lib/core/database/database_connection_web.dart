import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor openDatabaseConnection() {
  return DatabaseConnection.delayed(_openWebDatabase());
}

Future<DatabaseConnection> _openWebDatabase() async {
  final result = await WasmDatabase.open(
    databaseName: 'accounting_app',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.dart.js'),
  );

  if (result.chosenImplementation == WasmStorageImplementation.inMemory) {
    await result.resolvedExecutor.close();
    throw UnsupportedError(
      'This browser cannot provide persistent local storage for the database. '
      'Please enable website storage or use a supported Safari version.',
    );
  }

  return result.resolvedExecutor;
}
