sealed class InspectorConnectionState {
  const InspectorConnectionState();
}

final class Disconnected extends InspectorConnectionState {
  const Disconnected();
}

final class Connecting extends InspectorConnectionState {
  const Connecting();
}

final class Connected extends InspectorConnectionState {
  const Connected();
}

/// No event seen for the heartbeat watchdog window. Connection might be alive
/// but is not confirmed.
final class Stale extends InspectorConnectionState {
  const Stale();
}

final class Errored extends InspectorConnectionState {
  final String reason;
  const Errored(this.reason);
}
