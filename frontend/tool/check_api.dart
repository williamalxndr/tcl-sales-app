import 'dart:io';

import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/core/network/api_exception.dart';
import 'package:sales_app/features/service_status/data/service_status_repository.dart';

/// Developer smoke check using the same service/repository as the app.
Future<void> main(List<String> args) async {
  final baseUrl = Uri.parse(
    args.isEmpty ? 'http://localhost:8000/api/v1' : args.single,
  );
  final api = ApiClient(baseUrl: baseUrl);
  try {
    await ServiceStatusRepository(api).checkAvailability();
    stdout.writeln('PASS: Flutter repository -> DRF -> MySQL.');
  } on ApiException catch (error) {
    stderr.writeln('Service check failed: ${error.code}');
    exitCode = 1;
  } finally {
    api.close();
  }
}
