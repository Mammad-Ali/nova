/// The speedometer's scale: labelled marks spaced evenly around the dial, with
/// the speeds between two marks spread linearly. 5 Mbps and 500 Mbps are then
/// both readable on one dial, the way the dials of popular speed tests work,
/// and the scale never changes under the needle during a test — it only
/// steps up once, to [multiGig], on a line faster than [standard] can show.
class GaugeScale {
  const GaugeScale(this.marks);

  /// Ascending, starting at 0; the last is the dial's top.
  final List<double> marks;

  /// Every home connection up to gigabit.
  static const standard = GaugeScale([0, 5, 10, 50, 100, 250, 500, 750, 1000]);

  /// Multi-gigabit lines.
  static const multiGig = GaugeScale([0, 10, 50, 100, 250, 500, 1000, 2500, 5000, 10000]);

  double get max => marks.last;

  /// The scale that shows [mbps]: [standard] unless it would run off the top.
  static GaugeScale fitting(double mbps) => mbps > standard.max ? multiGig : standard;

  /// Where [mbps] sits on the dial, 0 at the start, 1 at the top mark.
  double fractionOf(double mbps) {
    if (!mbps.isFinite || mbps <= 0) return 0;
    final last = marks.length - 1;
    for (var i = 1; i <= last; i++) {
      if (mbps <= marks[i]) {
        final within = (mbps - marks[i - 1]) / (marks[i] - marks[i - 1]);
        return (i - 1 + within) / last;
      }
    }
    return 1;
  }

  /// Where mark [index] sits on the dial.
  double markFraction(int index) => index / (marks.length - 1);

  /// A mark's label: "750", "1G", "2.5G".
  static String label(double mbps) {
    if (mbps < 1000) return mbps.toStringAsFixed(0);
    final g = mbps / 1000;
    return '${g == g.roundToDouble() ? g.toStringAsFixed(0) : g.toStringAsFixed(1)}G';
  }
}
