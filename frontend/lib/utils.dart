Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  return <dynamic>[];
}

String asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

double asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(asString(value)) ?? fallback;
}

int asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(asString(value)) ?? fallback;
}

bool asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = asString(value).toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

String formatInt(dynamic value) {
  final number = asInt(value);
  final digits = number.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '${number < 0 ? '-' : ''}$buffer';
}

String formatPercent(dynamic value, {int decimals = 0}) {
  final number = asDouble(value) * 100;
  return '${number.toStringAsFixed(decimals)}%';
}

String titleCase(String value) {
  return value
      .toLowerCase()
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String prettyAction(String action) {
  return titleCase(action);
}

String prettyPii(String type) {
  switch (type) {
    case 'FINANCIAL_ACCOUNT':
      return 'Financial account';
    case 'FINANCIAL_AMOUNT':
      return 'Financial amount';
    case 'UPI_ID':
      return 'UPI ID';
    case 'AADHAAR':
      return 'Aadhaar';
    case 'PAN':
      return 'PAN';
    case 'GSTIN':
      return 'GSTIN';
    case 'IFSC':
      return 'IFSC';
    default:
      return titleCase(type);
  }
}

String formatNumber(dynamic value) => formatInt(value);

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String shortDate(dynamic iso) {
  final parsed = DateTime.tryParse(asString(iso));
  if (parsed == null) return asString(iso);
  final local = parsed.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_months[local.month - 1]}, $hour:$minute';
}

String clockTime(dynamic iso) {
  final parsed = DateTime.tryParse(asString(iso));
  if (parsed == null) return asString(iso);
  final local = parsed.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

String piiTypeSummary(List<dynamic> columns) {
  final types = <String>[];
  for (final raw in columns) {
    final column = asMap(raw);
    final type = asString(column['pii_type'], 'OTHER');
    if (type != 'OTHER' && !types.contains(type)) types.add(type);
  }
  if (types.isEmpty) return 'No PII detected';
  return types.map(prettyPii).join(', ');
}

String plural(int count, String singular, [String? pluralWord]) {
  return '$count ${count == 1 ? singular : (pluralWord ?? '${singular}s')}';
}
