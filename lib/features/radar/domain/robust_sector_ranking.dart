import 'radar_signal_model.dart';

extension RobustSectorRanking on SectorRssiAccumulator {
  SectorEstimate? robustStrongestEstimate({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final ranked = <({int sector, double rssi})>[];

    for (var sector = 0; sector < RadarMath.sectorCount; sector++) {
      final samples = samplesForSector(sector, now: timestamp);
      if (samples.isEmpty) continue;
      ranked.add((sector: sector, rssi: _median(samples)));
    }

    if (ranked.isEmpty) return null;

    ranked.sort((a, b) => b.rssi.compareTo(a.rssi));
    final best = ranked.first;
    final marginDb = ranked.length > 1
        ? (best.rssi - ranked[1].rssi).clamp(0.0, 12.0)
        : 0.0;
    final sampleCount = samplesForSector(best.sector, now: timestamp).length;
    final sampleConfidence = (sampleCount / windowSize).clamp(0.0, 1.0);
    final marginConfidence = (marginDb / 6.0).clamp(0.0, 1.0);
    final confidence =
        (sampleConfidence * 0.55 + marginConfidence * 0.45).clamp(0.0, 1.0);

    return SectorEstimate(
      sector: best.sector,
      rssi: best.rssi,
      confidence: confidence,
      sampleCount: sampleCount,
      marginDb: marginDb,
    );
  }
}

double _median(List<int> samples) {
  final sorted = List<int>.of(samples)..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle].toDouble();
  return (sorted[middle - 1] + sorted[middle]) / 2.0;
}
