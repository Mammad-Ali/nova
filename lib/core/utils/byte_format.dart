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