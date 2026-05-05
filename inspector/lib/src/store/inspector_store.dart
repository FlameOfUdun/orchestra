import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/inspector_state.dart';
import '../reducer/reduce.dart';
import '../transport/inspector_client.dart';
import '../transport/inspector_message.dart';

/// Owns [InspectorState]; subscribes to a transport, runs the reducer, and
/// notifies listeners on state change.
final class InspectorStore extends ChangeNotifier implements ValueListenable<InspectorState> {
  InspectorStore(this._client) {
    _subscription = _client.messages.listen(_onMessage);
  }

  final InspectorClient _client;
  late final StreamSubscription<InspectorMessage> _subscription;

  InspectorState _state = InspectorState.initial;

  @override
  InspectorState get value => _state;

  InspectorClient get client => _client;

  void _onMessage(InspectorMessage msg) {
    final next = reduce(_state, msg);
    if (identical(next, _state)) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
