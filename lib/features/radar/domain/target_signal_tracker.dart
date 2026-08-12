import 'radar_signal_model.dart';

enum TrackingSignalState { searching, candidate, locked, lost }

class TimedHeading {
  const TimedHeading({required this.degrees, required this.capturedAt});

  final double degrees;
  final DateTime capturedAt;
}

class TrackingSnapshot {
  const TrackingSnapshot({
    required this.state,
    required this.estimate,
    required this.lastSeenAt,
    required this.lockedSector,
  });

  final TrackingSignalState state;
  final SectorEstimate? estimate;
  final DateTime? lastSeenAt;
  final int? lockedSector;
}

/// Pure-domain tracker that joins RSSI samples with a near-simultaneous heading.
///
/// Samples outside [syncTolerance] are rejected so a stale compass reading does
/// not contaminate a radar sector. A sector must remain a strong candidate for
/// [lockDuration] before it is exposed as locked. A target becomes lost when no
/// accepted sample arrives for [lostAfter].
class TargetSignalTracker {
  TargetSignalTracker({
    SectorRssiAccumulator? accumulator,
    this.syncTolerance = const Duration(milliseconds: 250),
    this.lockDuration = const Duration(seconds: 3),
    this.lostAfter = const Duration(seconds: 3),
  }) : accumulator = accumulator ?? SectorRssiAccumulator() {
    if (syncTolerance.isNegative) {
      throw ArgumentError.value(syncTolerance, 'syncTolerance', 'Debe ser >= 0.');
    }
    if (lockDuration.isNegative) {
      throw ArgumentError.value(lockDuration, 'lockDuration', 'Debe ser >= 0.');
    }
    if (lostAfter <= Duration.zero) {
      throw ArgumentError.value(lostAfter, 'lostAfter', 'Debe ser > 0.');
    }
  }

  final SectorRssiAccumulator accumulator;
  final Duration syncTolerance;
  final Duration lockDuration;
  final Duration lostAfter;

  DateTime? _lastSeenAt;
  DateTime? _candidateSince;
  int? _candidateSector;
  int? _lockedSector;
  SectorEstimate? _lastEstimate;

  bool addSample({
    required int rssi,
    required DateTime capturedAt,
    required TimedHeading heading,
  }) {
    final skew = capturedAt.difference(heading.capturedAt).abs();
    if (skew > syncTolerance) return false;

    accumulator.add(headingDegrees: heading.degrees, rssi: rssi);
    _lastSeenAt = capturedAt;
    _lastEstimate = accumulator.strongestEstimate();
    _updateLock(capturedAt, _lastEstimate);
    return true;
  }

  TrackingSnapshot snapshot(DateTime now) {
    final lastSeenAt = _lastSeenAt;
    if (lastSeenAt == null) {
      return const TrackingSnapshot(
        state: TrackingSignalState.searching,
        estimate: null,
        lastSeenAt: null,
        lockedSector: null,
      );
    }

    if (now.difference(lastSeenAt) > lostAfter) {
      _candidateSince = null;
      _candidateSector = null;
      _lockedSector = null;
      return TrackingSnapshot(
        state: TrackingSignalState.lost,
        estimate: _lastEstimate,
        lastSeenAt: lastSeenAt,
        lockedSector: null,
      );
    }

    final state = _lockedSector != null
        ? TrackingSignalState.locked
        : _candidateSince != null
            ? TrackingSignalState.candidate
            : TrackingSignalState.searching;

    return TrackingSnapshot(
      state: state,
      estimate: _lastEstimate,
      lastSeenAt: lastSeenAt,
      lockedSector: _lockedSector,
    );
  }

  void reset() {
    _lastSeenAt = null;
    _candidateSince = null;
    _candidateSector = null;
    _lockedSector = null;
    _lastEstimate = null;
  }

  void _updateLock(DateTime capturedAt, SectorEstimate? estimate) {
    if (estimate == null || !estimate.isLockCandidate) {
      if (_lockedSector == null) {
        _candidateSince = null;
        _candidateSector = null;
      }
      return;
    }

    if (_lockedSector != null) {
      if (estimate.sector == _lockedSector) return;

      // Require a fresh full-duration candidate before moving an existing lock.
      if (_candidateSector != estimate.sector) {
        _candidateSector = estimate.sector;
        _candidateSince = capturedAt;
        return;
      }
      if (capturedAt.difference(_candidateSince!) >= lockDuration) {
        _lockedSector = estimate.sector;
        _candidateSince = null;
        _candidateSector = null;
      }
      return;
    }

    if (_candidateSector != estimate.sector) {
      _candidateSector = estimate.sector;
      _candidateSince = capturedAt;
      return;
    }

    if (capturedAt.difference(_candidateSince!) >= lockDuration) {
      _lockedSector = estimate.sector;
      _candidateSince = null;
      _candidateSector = null;
    }
  }
}

extension on Duration {
  Duration abs() => isNegative ? -this : this;
}
