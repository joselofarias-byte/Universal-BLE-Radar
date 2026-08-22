import 'radar_signal_model.dart';
import 'target_presence_tracker.dart';

enum RadarTurnDirection {
  unknown,
  aligned,
  left,
  right,
}

class RadarGuidance {
  const RadarGuidance({
    required this.direction,
    required this.signedDeltaDegrees,
    required this.isActionable,
    required this.proximity,
    required this.confidence,
  });

  static const double _maxWeakMarginDeadbandDegrees = 4.0;
  static const double _fullMarginDb = 6.0;

  final RadarTurnDirection direction;
  final double? signedDeltaDegrees;
  final bool isActionable;
  final ProximityBand? proximity;
  final double confidence;

  static RadarGuidance evaluate({
    required SectorEstimate? estimate,
    required TargetPresenceState presence,
    required double? currentHeadingDegrees,
  }) {
    final proximity = estimate == null
        ? null
        : RadarMath.proximityForRssi(estimate.rssi.round());
    final actionable = estimate != null &&
        estimate.isLockCandidate &&
        presence.isPresent &&
        !presence.isStale &&
        currentHeadingDegrees != null &&
        currentHeadingDegrees.isFinite;

    if (!actionable) {
      return RadarGuidance(
        direction: RadarTurnDirection.unknown,
        signedDeltaDegrees: null,
        isActionable: false,
        proximity: proximity,
        confidence: estimate?.confidence ?? 0.0,
      );
    }

    final targetHeading = estimate.sector * RadarMath.sectorSizeDegrees;
    final delta = _signedAngularDelta(targetHeading, currentHeadingDegrees);
    final halfSector = RadarMath.sectorSizeDegrees / 2;
    final alignedTolerance = halfSector + _weakMarginDeadband(estimate.marginDb);
    final direction = delta.abs() <= alignedTolerance
        ? RadarTurnDirection.aligned
        : delta > 0
            ? RadarTurnDirection.right
            : RadarTurnDirection.left;

    return RadarGuidance(
      direction: direction,
      signedDeltaDegrees: delta,
      isActionable: true,
      proximity: proximity,
      confidence: estimate.confidence,
    );
  }

  static double _weakMarginDeadband(double marginDb) {
    final normalizedMargin = (marginDb / _fullMarginDb).clamp(0.0, 1.0);
    return (1.0 - normalizedMargin) * _maxWeakMarginDeadbandDegrees;
  }

  static double _signedAngularDelta(double target, double current) {
    RadarMath.requireFinite(target, 'target');
    RadarMath.requireFinite(current, 'current');
    return ((target - current + 540) % 360) - 180;
  }
}
