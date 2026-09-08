class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
  });

  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;

  @override
  String toString() => 'ApiException($code, status: $statusCode)';
}
