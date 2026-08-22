import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble_radar/features/radar/domain/radar_guidance.dart';
import 'package:universal_ble_radar/features/radar/domain/radar_signal_model.dart';
import 'package:universal_ble_radar/features/radar/domain/target_presence_tracker.dart';

SectorEstimate estimate({
  required int sector,
  double rssi = -55,
  double confidence = 0.9,
  double marginDb = 6,
  int sampleCount = 25,
}) =>
    SectorEstimate(
      sector: sector,
      rssi: rssi,
      confidence: confidence,
      sampleCount: sampleCount,
      marginDb: marginDb,
    );

const present = TargetPresenceState(
  isPresent: true,
  isStale: false,
  age: Duration(milliseconds: 200),
);

void main() {
  test('marks heading inside strongest sector as aligned', () {
    final guidance = RadarGuidance.evaluate(
      estimate: estimate(sector: 0),
      presence: present,
      currentHeadingDegrees: 355,
    );

    expect(guidance.isActionable, isTrue);
    expect(guidance.direction, RadarTurnDirection.aligned);
    expect(guidance.signedDeltaDegrees, closeTo(5, 0.001));
    expect(guidance.proximity, ProximityBand.close);
  });

  test('uses shortest turn across north wraparound', () {
    final guidance = RadarGuidance.evaluate(
      estimate: estimate(sector: 1),
      presence: present,
      currentHeadingDegrees: 350,
    );

    expect(guidance.direction, RadarTurnDirection.right);
    expect(guidance.signedDeltaDegrees, closeTo(32.5, 0.001));
  });

  test('widens aligned deadband when sector margin is barely actionable', () {
    final guidance = RadarGuidance.evaluate(
      estimate: estimate(sector: 1, marginDb: 3.1),
      presence: present,
      currentHeadingDegrees: 9,
    );

    expect(guidance.isActionable, isTrue);
    expect(guidance.signedDeltaDegrees, closeTo(13.5, 0.001));
    expect(guidance.direction, RadarTurnDirection.aligned);
  });

  test('keeps normal turn threshold when sector margin is strong', () {
    final guidance = RadarGuidance.evaluate(
      estimate: estimate(sector: 1, marginDb: 6),
      presence: present,
      currentHeadingDegrees: 9,
    );

    expect(guidance.isActionable, isTrue);
    expect(guidance.signedDeltaDegrees, closeTo(13.5, 0.001));
    expect(guidance.direction, RadarTurnDirection.right);
  });

  test('gates directional advice when confidence is insufficient', () {
    final guidance = RadarGuidance.evaluate(
      estimate: estimate(sector: 4, confidence: 0.5, marginDb: 2),
      presence: present,
      currentHeadingDegrees: 0,
    );

    expect(guidance.isActionable, isFalse);
    expect(guidance.direction, RadarTurnDirection.unknown);
    expect(guidance.signedDeltaDegrees, isNull);
  });

  test('gates directional advice when target is stale', () {
    const stale = TargetPresenceState(
      isPresent: false,
      isStale: true,
      age: Duration(seconds: 5),
    );
    final guidance = RadarGuidance.evaluate(
      estimate: estimate(sector: 8),
      presence: stale,
      currentHeadingDegrees: 180,
    );

    expect(guidance.isActionable, isFalse);
    expect(guidance.direction, RadarTurnDirection.unknown);
  });

  test('does not invent proximity or direction without an estimate', () {
    final guidance = RadarGuidance.evaluate(
      estimate: null,
      presence: present,
      currentHeadingDegrees: 10,
    );

    expect(guidance.isActionable, isFalse);
    expect(guidance.proximity, isNull);
    expect(guidance.confidence, 0);
  });
}
