import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble_radar/features/radar/domain/radar_signal_model.dart';
import 'package:universal_ble_radar/features/radar/domain/robust_sector_ranking.dart';

void main() {
  group('RobustSectorRanking', () {
    test('ignores a single transient spike when ranking sectors', () {
      final accumulator = SectorRssiAccumulator(windowSize: 5, alpha: 1);

      for (var i = 0; i < 3; i++) {
        accumulator.add(headingDegrees: 0, rssi: -60);
        accumulator.add(headingDegrees: 90, rssi: -50);
      }
      accumulator.add(headingDegrees: 0, rssi: -20);

      expect(accumulator.strongestSector(), 0);

      final robust = accumulator.robustStrongestEstimate();
      expect(robust, isNotNull);
      expect(robust!.sector, 4);
      expect(robust.rssi, -50);
    });

    test('uses the midpoint median for an even sample count', () {
      final accumulator = SectorRssiAccumulator(windowSize: 4, alpha: 1);
      accumulator.add(headingDegrees: 180, rssi: -70);
      accumulator.add(headingDegrees: 180, rssi: -50);

      final robust = accumulator.robustStrongestEstimate();
      expect(robust, isNotNull);
      expect(robust!.sector, 8);
      expect(robust.rssi, -60);
    });

    test('preserves confidence and lock semantics', () {
      final accumulator = SectorRssiAccumulator(windowSize: 5, alpha: 1);
      for (var i = 0; i < 5; i++) {
        accumulator.add(headingDegrees: 90, rssi: -50);
        accumulator.add(headingDegrees: 180, rssi: -62);
      }

      final robust = accumulator.robustStrongestEstimate();
      expect(robust, isNotNull);
      expect(robust!.sector, 4);
      expect(robust.marginDb, 12);
      expect(robust.confidence, 1);
      expect(robust.isLockCandidate, isTrue);
    });
  });
}
