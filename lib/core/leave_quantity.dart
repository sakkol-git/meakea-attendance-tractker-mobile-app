/// Leave accounting is in hundredths of a day; keep that precision in UI copy.
String formatLeaveDays(num? value) {
  if (value == null || !value.isFinite) return '— days';
  final rounded = value.toStringAsFixed(2);
  final quantity = rounded.endsWith('.00')
      ? rounded.substring(0, rounded.length - 3)
      : rounded.endsWith('0')
      ? rounded.substring(0, rounded.length - 1)
      : rounded;
  return '$quantity ${double.parse(rounded).abs() == 1 ? 'day' : 'days'}';
}

String leaveBalancePeriod(int? year) =>
    year == null ? 'Balance period unavailable' : 'Valid through 31 Dec $year';
