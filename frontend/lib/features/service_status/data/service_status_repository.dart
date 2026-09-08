import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class ServiceStatusRepository {
  ServiceStatusRepository(this._api);

  final ApiClient _api;

  Future<void> checkAvailability() async {
    final data = await _api.getObject('health/ready');
    if (data['status'] != 'ready' || data['database'] != 'ok') {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'The service returned an unexpected status.',
      );
    }
  }
}
