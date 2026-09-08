import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/service_status/data/service_status_repository.dart';

void main() {
  final config = AppConfig.fromEnvironment();
  final api = ApiClient(baseUrl: config.apiBaseUrl);
  runApp(SalesApp(repository: ServiceStatusRepository(api)));
}
