import 'package:orchestra/inspector_export.dart';

import '../domain/connection_state.dart';

sealed class InspectorMessage {
  const InspectorMessage();
}

final class ConnectionChanged extends InspectorMessage {
  final InspectorConnectionState state;
  const ConnectionChanged(this.state);
}

final class Bootstrap extends InspectorMessage {
  final SubscribeResponseDto data;
  const Bootstrap(this.data);
}

final class RuntimeEvent extends InspectorMessage {
  final EventDto event;
  const RuntimeEvent(this.event);
}

final class TransportError extends InspectorMessage {
  final Object error;
  final StackTrace stack;
  const TransportError(this.error, this.stack);
}
