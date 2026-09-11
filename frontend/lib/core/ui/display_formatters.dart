const _indonesianMonths = <String>[
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String formatApiDateTime(String? value, {String fallback = '—'}) {
  if (value == null || value.isEmpty) return fallback;
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  final dateLabel =
      '${date.day} ${_indonesianMonths[date.month - 1]} '
      '${date.year}';
  if (!value.contains('T')) return dateLabel;
  String two(int number) => number.toString().padLeft(2, '0');
  return '$dateLabel, ${two(date.hour)}.${two(date.minute)}';
}

String formatFileSize(int bytes) {
  if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}
