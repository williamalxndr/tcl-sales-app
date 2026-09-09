class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
    this.details = const [],
  });

  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;
  final List<ApiErrorDetail> details;

  @override
  String toString() => 'ApiException($code, status: $statusCode)';
}

class ApiErrorDetail {
  const ApiErrorDetail({this.field, required this.code, required this.message});

  final String? field;
  final String code;
  final String message;

  factory ApiErrorDetail.fromJson(Map<String, dynamic> json) {
    return ApiErrorDetail(
      field: json['field'] as String?,
      code: json['code'] as String? ?? 'INVALID',
      message: json['message'] as String? ?? 'Nilai tidak valid.',
    );
  }
}
