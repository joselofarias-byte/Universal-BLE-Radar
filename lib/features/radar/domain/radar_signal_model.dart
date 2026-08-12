enum ProximityBand {
  veryClose,
  close,
  nearby,
  distant,
  veryDistant,
}

class RadarMath {
  static const int sectorCount = 16;
  static const double sectorSizeDegrees = 360 / sectorCount;
  static const double defaultEmaAlpha = 0.3;

  static ProximityBand proximityForRssi(int rssi) {
    if (rssi >= -45) return ProximityBand.veryClose;
    if (rssi >= -60) return ProximityBand.close;
    if (rssi >= -75) return ProximityBand.nearby;
    if (rssi >= -90) return ProximityBand.distant;
    return ProximityBand.veryDistant;
  }

  static int sectorForHeading(double headingDegrees) {
    requireFinite(headingDegrees, 'headingDegrees');
    final normalized = ((headingDegrees % 360) + 360) % 360;
    return ((normalized + sectorSizeDegrees / 2) / sectorSizeDegrees).floor() %
        sectorCount;
  }

  static double ema(double previous, double sample,
      {double alpha = defaultEmaAlpha}) {
    requireFinite(previous, 'previous');
    requireFinite(sample, 'sample');
    if (alpha <= 0 || alpha > 1) {
      throw ArgumentError.value(alpha, 'alpha', 'Debe estar en (0, 1].');
    }
    return alpha * sample + (1 - alpha) * previous;
  }

  static double angularDelta(double a, double b) {
    requireFinite(a, 'a');
    requireFinite(b, 'b');
    final delta = ((a - b + 540) % 360) - 180;
    return delta.abs();
  }

  static void requireFinite(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'Debe ser finito.');
    }
  }
}

class SectorRssiAccumulator {
  SectorRssiAccumulator({
    this.alpha = RadarMath.defaultEmaAlpha,
    this.windowSize = 25,
  }) {
    if (alpha <= 0 || alpha > 1) {
      throw ArgumentError.value(alpha, 'alpha', 'Debe estar en (0, 1].');
    }
    if (windowSize <= 0) {
      throw ArgumentError.value(windowSize, 'windowSize', 'Debe ser > 0.');
    }
  }

  final double alpha;
  final int windowSize;
  final List<List<int>> _windows =
      List.generate(RadarMath.sectorCount, (_) => <int>[]);
  final List<double?> _ema =
      List<double?>.filled(RadarMath.sectorCount, null);

  void add({required double headingDegrees, required int rssi}) {
    final sector = RadarMath.sectorForHeading(headingDegrees);
    final window = _windows[sector];
    window.add(rssi);
    if (window.length > windowSize) {
      window.removeAt(0);
    }
    final previous = _ema[sector];
    _ema[sector] = previous == null
        ? rssi.toDouble()
        : RadarMath.ema(previous, rssi.toDouble(), alpha: alpha);
  }

  double? emaForSector(int sector) {
    _validateSector(sector);
    return _ema[sector];
  }

  List<int> samplesForSector(int sector) {
    _validateSector(sector);
    return List<int>.unmodifiable(_windows[sector]);
  }

  int? strongestSector() {
    int? best;
    double? bestValue;
    for (var i = 0; i < _ema.length; i++) {
      final value = _ema[i];
      if (value == null) continue;
      if (bestValue == null || value > bestValue) {
        best = i;
        bestValue = value;
      }
    }
    return best;
  }

  void _validateSector(int sector) {
    if (sector < 0 || sector >= RadarMath.sectorCount) {
      throw RangeError.range(sector, 0, RadarMath.sectorCount - 1, 'sector');
    }
  }
}
