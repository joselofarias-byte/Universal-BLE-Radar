import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble_radar/features/radar/domain/radar_signal_model.dart';
import 'package:universal_ble_radar/features/radar/domain/robust_sector_ranking.dart';

void main() {
  group('stale sector expiry', () {
    test('expired samples no longer dominate robust ranking', () {
      final accumulator = SectorRssiAccumulator(
        sampleMaxAge: const Duration(seconds: 5),
      );
      final t0 = DateTime.utc(2026, 8, 22, 10);

      for (var i = 0; i < 12; i++) {
        accumulator.add(
          headingDegrees: 0,
          rssi: -40,
          observedAt: t0.add(Duration(milliseconds: i * 100)),
        );
      }

      final t1 = t0.add(const Duration(seconds: 7));
      for (var i = 0; i < 12; i++) {
        accumulator.add(
          headingDegrees: 90,
          rssi: -58,
          observedAt: t1.add(Duration(milliseconds: i * 100)),
        );
      }

      final estimate = accumulator.robustStrongestEstimate(
        now: t1.add(const Duration(seconds: 2)),
      );

      expect(estimate, isNotNull);
      expect(estimate!.sector, RadarMath.sectorForHeading(90));
      expect(accumulator.samplesForSector(0, now: t1), isEmpty);
    });

    test('pruning recomputes EMA from remaining fresh samples', () {
      final accumulator = SectorRssiAccumulator(
        alpha: 0.5,
        sampleMaxAge: const Duration(seconds: 5),
      );
      final t0 = DateTime.utc(2026, 8, 22, 10);

      accumulator.add(headingDegrees: 0, rssi: -35, observedAt: t0);
      accumulator.add(
        headingDegrees: 0,
        rssi: -65,
        observedAt: t0.add(const Duration(seconds: 4)),
      );

      expect(accumulator.emaForSector(0, now: t0.add(const Duration(seconds: 4))), -50);
      expect(accumulator.emaForSector(0, now: t0.add(const Duration(seconds: 6))), -65);
    });

    test('reset clears samples and timestamp state', () {
      final accumulator = SectorRssiAccumulator();
      final now = DateTime.utc(2026, 8, 22, 10);

      accumulator.add(headingDegrees: 45, rssi: -55, observedAt: now);
      accumulator.reset();

      expect(accumulator.samplesForSector(
        RadarMath.sectorForHeading(45),
        now: now,
      ), isEmpty);
      expect(accumulator.robustStrongestEstimate(now: now), isNull);
    });
  });
}
