class FormattedRate {
  const FormattedRate(this.value, this.unit);
  final String value;
  final String unit;

  @override
  String toString() => '$value $unit';
}

const int _kib = 1024;
const List<String> _rateUnits = ['B/s', 'KB/s', 'MB/s', 'GB/s', 'TB/s'];
const List<String> _sizeUnits = ['B', 'KB', 'MB', 'GB', 'TB'];

FormattedRate formatRate(num bytesPerSecond) => _humanize(bytesPerSecond, _rateUnits);
FormattedRate formatBytes(num bytes) => _humanize(bytes, _sizeUnits);

/// Exactly as wide as a full stop: stands in for the decimal point a
/// three-digit number doesn't have.
const String punctuationSpace = ' ';

/// [bytes] to three significant digits and a one-letter unit — "6.01K",
/// "62.0K", "620K" — for text that must not change width, like the menu-bar
/// title. With equal-width digits all three take the same room: each has
/// three digits, and "620" gets a [punctuationSpace] where the others have a
/// point. Units switch before a fourth digit would appear, and start at K so
/// idle traffic doesn't flicker in and out of "B".
///
/// [base] and [units] switch it to bits: 1000 and k, M, G.
String formatFixedWidth(
  num bytes, {
  int base = _kib,
  // Up to E, so even a 64-bit counter's largest value keeps three digits.
  List<String> units = const ['K', 'M', 'G', 'T', 'P', 'E'],
}) {
  final raw = bytes.toDouble();
  var value = (raw.isFinite && raw > 0 ? raw : 0.0) / base;
  var i = 0;
  while (value >= 999.5 && i < units.length - 1) {
    value /= base;
    i++;
  }
  // The bounds sit where rounding would add a digit: 9.996 is "10.0", not
  // "10.00".
  final number = value < 9.995
      ? value.toStringAsFixed(2)
      : value < 99.95
          ? value.toStringAsFixed(1)
          : '$punctuationSpace${value.toStringAsFixed(0)}';
  return number + units[i];
}

/// [bytesPerSecond] in bits — "48.1Mbps" — at the same fixed width as
/// [formatFixedWidth].
String formatFixedWidthBits(num bytesPerSecond) =>
    '${formatFixedWidth(bytesPerSecond * 8, base: 1000, units: const ['k', 'M', 'G', 'T', 'P', 'E'])}bps';

FormattedRate _humanize(num amount, List<String> units) {
  var value = amount.toDouble();
  if (!value.isFinite || value < 0) value = 0;
  var i = 0;
  while (value >= _kib && i < units.length - 1) {
    value /= _kib;
    i++;
  }
  final decimals = i == 0 ? 0 : (value >= 100 ? 0 : (value >= 10 ? 1 : 2));
  return FormattedRate(value.toStringAsFixed(decimals), units[i]);
}