import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/database/database_provider.dart';
import '../../data/platform_data_file_gateway.dart';
import '../../domain/data_file_gateway.dart';
import '../../domain/data_management_service.dart';

final dataFileGatewayProvider = Provider<DataFileGateway>(
  (ref) => const PlatformDataFileGateway(),
);

final dataManagementServiceProvider = Provider<DataManagementService>(
  (ref) => DataManagementService(
    ref.watch(databaseProvider),
    ref.watch(dataFileGatewayProvider),
  ),
);

final dataSummaryProvider = FutureProvider<DataSummary>(
  (ref) => ref.watch(dataManagementServiceProvider).loadSummary(),
);

class AppVersionInfo {
  const AppVersionInfo({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;
}

final appVersionProvider = FutureProvider<AppVersionInfo>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppVersionInfo(version: info.version, buildNumber: info.buildNumber);
});
