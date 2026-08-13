class TargetPresenceState {
  const TargetPresenceState({
    required this.isPresent,
    required this.isStale,
    required this.age,
  });

  final bool isPresent;
  final bool isStale;
  final Duration age;
}

class TargetPresenceTracker {
  TargetPresenceTracker({this.timeout = const Duration(seconds: 4)}) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Debe ser mayor que cero.');
    }
  }

  final Duration timeout;
  DateTime? _lastSeenAt;

  DateTime? get lastSeenAt => _lastSeenAt;

  void markSeen(DateTime at) {
    _lastSeenAt = at;
  }

  void reset() {
    _lastSeenAt = null;
  }

  TargetPresenceState stateAt(DateTime now) {
    final lastSeen = _lastSeenAt;
    if (lastSeen == null) {
      return const TargetPresenceState(
        isPresent: false,
        isStale: true,
        age: Duration.zero,
      );
    }

    final rawAge = now.difference(lastSeen);
    final age = rawAge.isNegative ? Duration.zero : rawAge;
    final stale = age > timeout;
    return TargetPresenceState(
      isPresent: !stale,
      isStale: stale,
      age: age,
    );
  }
}
