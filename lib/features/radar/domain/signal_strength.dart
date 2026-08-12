enum ProximityBand { veryClose, close, nearby, distant, veryDistant }

ProximityBand proximityForRssi(int rssi) {
  if (rssi >= -45) return ProximityBand.veryClose;
  if (rssi >= -60) return ProximityBand.close;
  if (rssi >= -75) return ProximityBand.nearby;
  if (rssi >= -90) return ProximityBand.distant;
  return ProximityBand.veryDistant;
}

class EmaRssiFilter {
  EmaRssiFilter({this.alpha = 0.3}) {
    if (alpha <= 0 || alpha > 1) {
      throw ArgumentError.value(alpha, 'alpha', 'must be in (0, 1]');
    }
  }

  final double alpha;
  double? _value;

  double add(num sample) {
    final current = sample.toDouble();
    _value = _value == null ? current : alpha * current + (1 - alpha) * _value!;
    return _value!;
  }

  double? get value => _value;

  void reset() => _value = null;
}
