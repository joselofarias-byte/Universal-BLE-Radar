import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble_radar/features/radar/domain/radar_signal_model.dart';
import 'package:universal_ble_radar/features/radar/domain/target_signal_tracker.dart';

void main() {
  group('TargetSignalTracker', () {
    test('rechaza heading fuera de la tolerancia temporal', () {
      final tracker = TargetSignalTracker(
        accumulator: SectorRssiAccumulator(windowSize: 1),
      );
      final sampleAt = DateTime.utc(2026, 8, 12, 12);

      final accepted = tracker.addSample(
        rssi: -50,
        capturedAt: sampleAt,
        heading: TimedHeading(
          degrees: 90,
          capturedAt: sampleAt.subtract(const Duration(milliseconds: 251)),
        ),
      );

      expect(accepted, isFalse);
      expect(tracker.snapshot(sampleAt).state, TrackingSignalState.searching);
    });

    test('bloquea sólo después de tres segundos de candidato estable', () {
      final tracker = TargetSignalTracker(
        accumulator: SectorRssiAccumulator(windowSize: 1),
      );
      final start = DateTime.utc(2026, 8, 12, 12);

      for (final seconds in [0, 1, 2]) {
        final at = start.add(Duration(seconds: seconds));
        expect(
          tracker.addSample(
            rssi: -45,
            capturedAt: at,
            heading: TimedHeading(degrees: 90, capturedAt: at),
          ),
          isTrue,
        );
      }

      expect(
        tracker.snapshot(start.add(const Duration(seconds: 2))).state,
        TrackingSignalState.candidate,
      );

      final lockAt = start.add(const Duration(seconds: 3));
      tracker.addSample(
        rssi: -44,
        capturedAt: lockAt,
        heading: TimedHeading(degrees: 90, capturedAt: lockAt),
      );
      final snapshot = tracker.snapshot(lockAt);

      expect(snapshot.state, TrackingSignalState.locked);
      expect(snapshot.lockedSector, RadarMath.sectorForHeading(90));
      expect(snapshot.estimate?.confidence, 1.0);
    });

    test('marca el objetivo perdido y libera el lock', () {
      final tracker = TargetSignalTracker(
        accumulator: SectorRssiAccumulator(windowSize: 1),
        lockDuration: Duration.zero,
        lostAfter: const Duration(seconds: 2),
      );
      final at = DateTime.utc(2026, 8, 12, 12);

      tracker.addSample(
        rssi: -40,
        capturedAt: at,
        heading: TimedHeading(degrees: 180, capturedAt: at),
      );
      tracker.addSample(
        rssi: -40,
        capturedAt: at,
        heading: TimedHeading(degrees: 180, capturedAt: at),
      );
      expect(tracker.snapshot(at).state, TrackingSignalState.locked);

      final lost = tracker.snapshot(at.add(const Duration(milliseconds: 2001)));
      expect(lost.state, TrackingSignalState.lost);
      expect(lost.lockedSector, isNull);
    });
  });
}
