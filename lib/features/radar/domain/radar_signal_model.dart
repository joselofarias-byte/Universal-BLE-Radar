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
    return ((normalized + sectorSizeDegrees / 2) / sectorSizeDegrees).floor() % sectorCount;
  }

  static double ema(double previous, double sample, {double alpha = defaultEmaAlpha}) {
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

class SectorEstimate {
  const SectorEstimate({
    required this.sector,
    required this.rssi,
    required this.confidence,
    required this.sampleCount,
    required this.marginDb,
  });

  final int sector;
  final double rssi;
  final double confidence;
  final int sampleCount;
  final double marginDb;

  bool get isLockCandidate => confidence >= 0.7 && marginDb >= 3.0;
}

class SectorRssiAccumulator {
  SectorRssiAccumulator({this.alpha = RadarMath.defaultEmaAlpha, this.windowSize = 25}) {
    if (alpha <= 0 || alpha > 1) {
      throw ArgumentError.value(alpha, 'alpha', 'Debe estar en (0, 1].');
    }
    if (windowSize <= 0) {
      throw ArgumentError.value(windowSize, 'windowSize', 'Debe ser > 0.');
    }
  }

  final double alpha;
  final int windowSize;
  final List<List<int>> _windows = List.generate(RadarMath.sectorCount, (_) => <int>[]);
  final List<double?> _ema = List<double?>.filled(RadarMath.sectorCount, null);

  void add({required double headingDegrees, required int rssi}) {
    final sector = RadarMath.sectorForHeading(headingDegrees);
    final window = _windows[sector];
    window.add(rssi);
    if (window.length > windowSize) window.removeAt(0);
    final previous = _ema[sector];
    _ema[sector] = previous == null ? rssi.toDouble() : RadarMath.ema(previous, rssi.toDouble(), alpha: alpha);
  }

  double? emaForSector(int sector) {
    _validateSector(sector);
    return _ema[sector];
  }

  List<int> samplesForSector(int sector) {
    _validateSector(sector);
    return List<int>.unmodifiable(_windows[sector]);
  }

  int? strongestSector() => strongestEstimate()?.sector;

  SectorEstimate? strongestEstimate() {
    final ranked = <({int sector, double rssi})>[];
    for (var i = 0; i < _ema.length; i++) {
      final value = _ema[i];
      if (value != null) ranked.add((sector: i, rssi: value));
    }
    if (ranked.isEmpty) return null;

    ranked.sort((a, b) => b.rssi.compareTo(a.rssi));
    final best = ranked.first;
    final second = ranked.length > 1 ? ranked[1].rssi : best.rssi - 12.0;
    final marginDb = (best.rssi - second).clamp(0.0, 12.0);
    final sampleCount = _windows[best.sector].length;
    final sampleConfidence = (sampleCount / windowSize).clamp(0.0, 1.0);
    final marginConfidence = (marginDb / 6.0).clamp(0.0, 1.0);
    final confidence = (sampleConfidence * 0.55 + marginConfidence * 0.45).clamp(0.0, 1.0);

    return SectorEstimate(
      sector: best.sector,
      rssi: best.rssi,
      confidence: confidence,
      sampleCount: sampleCount,
      marginDb: marginDb,
    );
  }

  void _validateSector(int sector) {
    if (sector < 0 || sector >= RadarMath.sectorCount) {
      throw RangeError.range(sector, 0, RadarMath.sectorCount - 1, 'sector');
    }
  }
}
