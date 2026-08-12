import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble_radar/features/radar/domain/signal_strength.dart';

void main() {
  group('proximityForRssi', () {
    test('matches project thresholds', () {
      expect(proximityForRssi(-45), ProximityBand.veryClose);
      expect(proximityForRssi(-46), ProximityBand.close);
      expect(proximityForRssi(-60), ProximityBand.close);
      expect(proximityForRssi(-61), ProximityBand.nearby);
      expect(proximityForRssi(-75), ProximityBand.nearby);
      expect(proximityForRssi(-76), ProximityBand.distant);
      expect(proximityForRssi(-90), ProximityBand.distant);
      expect(proximityForRssi(-91), ProximityBand.veryDistant);
    });
  });

  group('EmaRssiFilter', () {
    test('uses alpha 0.3 by default', () {
      final filter = EmaRssiFilter();
      expect(filter.add(-70), -70);
      expect(filter.add(-60), closeTo(-67, 0.0001));
    });

    test('reset clears state', () {
      final filter = EmaRssiFilter()..add(-70);
      filter.reset();
      expect(filter.value, isNull);
      expect(filter.add(-50), -50);
    });

    test('rejects invalid alpha', () {
      expect(() => EmaRssiFilter(alpha: 0), throwsArgumentError);
      expect(() => EmaRssiFilter(alpha: 1.1), throwsArgumentError);
    });
  });
}
