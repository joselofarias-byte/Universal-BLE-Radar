import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble_radar/features/radar/domain/radar_signal_model.dart';

void main() {
  group('RadarMath proximity', () {
    test('matches configured RSSI bands', () {
      expect(RadarMath.proximityForRssi(-45), ProximityBand.veryClose);
      expect(RadarMath.proximityForRssi(-46), ProximityBand.close);
      expect(RadarMath.proximityForRssi(-60), ProximityBand.close);
      expect(RadarMath.proximityForRssi(-61), ProximityBand.nearby);
      expect(RadarMath.proximityForRssi(-75), ProximityBand.nearby);
      expect(RadarMath.proximityForRssi(-76), ProximityBand.distant);
      expect(RadarMath.proximityForRssi(-90), ProximityBand.distant);
      expect(RadarMath.proximityForRssi(-91), ProximityBand.veryDistant);
    });
  });

  group('RadarMath sectors', () {
    test('normalizes headings into 16 sectors', () {
      expect(RadarMath.sectorForHeading(0), 0);
      expect(RadarMath.sectorForHeading(22.5), 1);
      expect(RadarMath.sectorForHeading(359), 0);
      expect(RadarMath.sectorForHeading(-22.5), 15);
    });

    test('computes shortest angular delta', () {
      expect(RadarMath.angularDelta(359, 1), 2);
      expect(RadarMath.angularDelta(10, 190), 180);
    });
  });

  group('SectorRssiAccumulator', () {
    test('keeps bounded window and EMA', () {
      final accumulator = SectorRssiAccumulator(windowSize: 2, alpha: 0.5);
      accumulator.add(headingDegrees: 0, rssi: -80);
      accumulator.add(headingDegrees: 0, rssi: -60);
      accumulator.add(headingDegrees: 0, rssi: -40);
      expect(accumulator.samplesForSector(0), [-60, -40]);
      expect(accumulator.emaForSector(0), -55);
    });

    test('finds strongest sector', () {
      final accumulator = SectorRssiAccumulator();
      accumulator.add(headingDegrees: 0, rssi: -80);
      accumulator.add(headingDegrees: 90, rssi: -50);
      expect(accumulator.strongestSector(), 4);
    });

    test('confidence grows with samples and RSSI margin', () {
      final accumulator = SectorRssiAccumulator(windowSize: 5, alpha: 1);
      for (var i = 0; i < 5; i++) {
        accumulator.add(headingDegrees: 90, rssi: -50);
        accumulator.add(headingDegrees: 180, rssi: -62);
      }
      final estimate = accumulator.strongestEstimate();
      expect(estimate, isNotNull);
      expect(estimate!.sector, 4);
      expect(estimate.sampleCount, 5);
      expect(estimate.marginDb, 12);
      expect(estimate.confidence, 1);
      expect(estimate.isLockCandidate, isTrue);
    });

    test('does not lock on a narrow RSSI margin', () {
      final accumulator = SectorRssiAccumulator(windowSize: 5, alpha: 1);
      for (var i = 0; i < 5; i++) {
        accumulator.add(headingDegrees: 0, rssi: -55);
        accumulator.add(headingDegrees: 22.5, rssi: -53);
      }
      final estimate = accumulator.strongestEstimate();
      expect(estimate, isNotNull);
      expect(estimate!.sector, 1);
      expect(estimate.marginDb, 2);
      expect(estimate.isLockCandidate, isFalse);
    });
  });
}
