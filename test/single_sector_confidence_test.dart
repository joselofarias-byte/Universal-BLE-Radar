import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble_radar/features/radar/domain/radar_signal_model.dart';
import 'package:universal_ble_radar/features/radar/domain/robust_sector_ranking.dart';

void main() {
  group('comparative sector confidence', () {
    test('EMA estimate never locks with evidence from only one sector', () {
      final accumulator = SectorRssiAccumulator(windowSize: 5, alpha: 1);
      for (var i = 0; i < 5; i++) {
        accumulator.add(headingDegrees: 90, rssi: -45);
      }

      final estimate = accumulator.strongestEstimate();
      expect(estimate, isNotNull);
      expect(estimate!.sector, 4);
      expect(estimate.sampleCount, 5);
      expect(estimate.marginDb, 0);
      expect(estimate.isLockCandidate, isFalse);
    });

    test('robust estimate also requires a comparison sector before locking', () {
      final accumulator = SectorRssiAccumulator(windowSize: 5, alpha: 1);
      for (var i = 0; i < 5; i++) {
        accumulator.add(headingDegrees: 90, rssi: -45);
      }

      final estimate = accumulator.robustStrongestEstimate();
      expect(estimate, isNotNull);
      expect(estimate!.sector, 4);
      expect(estimate.marginDb, 0);
      expect(estimate.isLockCandidate, isFalse);
    });

    test('lock becomes possible after a clearly weaker comparison sector', () {
      final accumulator = SectorRssiAccumulator(windowSize: 5, alpha: 1);
      for (var i = 0; i < 5; i++) {
        accumulator.add(headingDegrees: 90, rssi: -45);
        accumulator.add(headingDegrees: 180, rssi: -60);
      }

      final ema = accumulator.strongestEstimate();
      final robust = accumulator.robustStrongestEstimate();
      expect(ema, isNotNull);
      expect(robust, isNotNull);
      expect(ema!.marginDb, 12);
      expect(robust!.marginDb, 12);
      expect(ema.isLockCandidate, isTrue);
      expect(robust.isLockCandidate, isTrue);
    });
  });
}
