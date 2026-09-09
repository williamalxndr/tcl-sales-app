class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.employeeNumber,
    required this.email,
    required this.status,
    required this.roles,
    required this.timeZone,
    required this.locationIds,
    this.jobTitle,
    this.checkerId,
  });

  final String id;
  final String fullName;
  final String employeeNumber;
  final String email;
  final String? jobTitle;
  final String status;
  final List<String> roles;
  final String timeZone;
  final List<String> locationIds;
  final String? checkerId;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    List<String> strings(String name) =>
        (json[name] as List<dynamic>? ?? const []).whereType<String>().toList(
          growable: false,
        );
    return UserProfile(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      employeeNumber: json['employeeNumber'] as String? ?? '',
      email: json['email'] as String? ?? '',
      jobTitle: json['jobTitle'] as String?,
      status: json['status'] as String? ?? '',
      roles: strings('roles'),
      timeZone: json['timeZone'] as String? ?? 'Asia/Jakarta',
      locationIds: strings('locationIds'),
      checkerId: json['checkerId'] as String?,
    );
  }

  String get initials {
    final names = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty);
    return names.take(2).map((item) => item[0].toUpperCase()).join();
  }

  String get primaryRole => roles.isEmpty ? 'Karyawan' : roles.first;
}
