import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/service.dart';
import 'package:orchestra/inspector_export.dart';
import 'package:vm_service/vm_service.dart';

import '../domain/connection_state.dart';
import 'inspector_message.dart';

/// Transport contract: deliver wire messages to the store.
abstract interface class InspectorClient {
  Stream<InspectorMessage> get messages;
  Future<void> connect();
  Future<void> disconnect();
  Future<void> resync();
  Future<void> dispose();
}

const Duration _kHeartbeatTimeout = Duration(seconds: 6);
const Duration _kServiceWaitTimeout = Duration(seconds: 30);
const Duration _kServicePollInterval = Duration(milliseconds: 100);

/// Real DevTools-extension client: subscribes via service extension and
/// listens on the `Extension` event stream filtered by [kInspectorEventStream].
final class DevToolsInspectorClient implements InspectorClient {
  DevToolsInspectorClient(this._serviceManager);

  final ServiceManager _serviceManager;

  final _controller = StreamController<InspectorMessage>.broadcast();
  StreamSubscription<Event>? _eventSubscription;
  Timer? _watchdog;
  String? _sessionId;
  int? _lastSeq;
  bool _resyncInFlight = false;

  @override
  Stream<InspectorMessage> get messages => _controller.stream;

  @override
  Future<void> connect() async {
    _emit(const ConnectionChanged(Connecting()));

    try {
      await _waitForService();
    } catch (e, s) {
      _emit(ConnectionChanged(Errored(e.toString())));
      _controller.add(TransportError(e, s));
      return;
    }

    final service = _serviceManager.service!;
    try {
      await service.streamListen(EventStreams.kExtension);
    } catch (_) {
      // Already listening — ignore.
    }
    _eventSubscription = service.onExtensionEvent.listen(_onExtensionEvent);

    try {
      final response = await _callExtension(kSubscribeExtension);
      final data = SubscribeResponseDto.fromJson(response);
      _sessionId = data.sessionId;
      _lastSeq = data.seq;
      _emit(Bootstrap(data));
      _emit(const ConnectionChanged(Connected()));
      _resetWatchdog();
    } catch (e, s) {
      _emit(ConnectionChanged(Errored('subscribe failed: $e')));
      _controller.add(TransportError(e, s));
    }
  }

  @override
  Future<void> disconnect() async {
    _watchdog?.cancel();
    _watchdog = null;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    final service = _serviceManager.service;
    if (service != null) {
      try {
        await _callExtension(kUnsubscribeExtension);
      } catch (_) {
        // Best effort.
      }
    }
    _emit(const ConnectionChanged(Disconnected()));
  }

  @override
  Future<void> resync() async {
    if (_resyncInFlight) return;
    _resyncInFlight = true;
    try {
      final response = await _callExtension(kResyncExtension);
      final data = SubscribeResponseDto.fromJson(response);
      _sessionId = data.sessionId;
      _lastSeq = data.seq;
      _emit(Bootstrap(data));
      _resetWatchdog();
    } catch (e, s) {
      _controller.add(TransportError(e, s));
    } finally {
      _resyncInFlight = false;
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
  }

  // ─── Internal ──────────────────────────────────────────────────────────

  void _onExtensionEvent(Event event) {
    if (event.extensionKind != kInspectorEventStream) return;
    final raw = event.extensionData?.data;
    if (raw == null) return;

    final Map<String, Object?> json;
    try {
      final Object payload = raw;
      final decoded = payload is String ? jsonDecode(payload) : payload;
      json = (decoded as Map).cast<String, Object?>();
    } catch (e, s) {
      _controller.add(TransportError(e, s));
      return;
    }

    final EventDto dto;
    try {
      dto = EventDto.fromJson(json);
    } catch (e, s) {
      _controller.add(TransportError(e, s));
      return;
    }

    if (_sessionId != null && dto.sessionId != _sessionId) {
      // Stale event from a previous session — trigger resync.
      unawaited(resync());
      return;
    }

    final last = _lastSeq;
    if (last != null && dto.seq != last + 1) {
      unawaited(resync());
      return;
    }
    _lastSeq = dto.seq;

    _resetWatchdog();
    _emit(RuntimeEvent(dto));
  }

  Future<Map<String, Object?>> _callExtension(String method) async {
    final service = _serviceManager.service;
    final isolate = _serviceManager.isolateManager.selectedIsolate.value;
    if (service == null || isolate == null) {
      throw StateError('Service or isolate not available');
    }
    final response = await service.callServiceExtension(method, isolateId: isolate.id);
    final json = response.json;
    if (json == null) {
      throw StateError('No response from $method');
    }
    final result = json['result'];
    if (result is String) {
      return (jsonDecode(result) as Map).cast<String, Object?>();
    }
    return json.cast<String, Object?>();
  }

  Future<void> _waitForService() async {
    final deadline = DateTime.now().add(_kServiceWaitTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_serviceManager.service != null &&
          _serviceManager.isolateManager.selectedIsolate.value != null) {
        return;
      }
      await Future.delayed(_kServicePollInterval);
    }
    throw TimeoutException('Service manager not available within timeout');
  }

  void _resetWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_kHeartbeatTimeout, () {
      _emit(const ConnectionChanged(Stale()));
    });
  }

  void _emit(InspectorMessage msg) {
    if (_controller.isClosed) return;
    _controller.add(msg);
  }
}

/// In-memory client for tests and fixture-driven development.
final class FakeInspectorClient implements InspectorClient {
  FakeInspectorClient([Iterable<InspectorMessage>? initial])
      : _initial = List.of(initial ?? const []);

  final List<InspectorMessage> _initial;
  final _controller = StreamController<InspectorMessage>.broadcast();

  @override
  Stream<InspectorMessage> get messages => _controller.stream;

  /// Push a message on demand from a test.
  void push(InspectorMessage msg) {
    if (_controller.isClosed) return;
    _controller.add(msg);
  }

  @override
  Future<void> connect() async {
    for (final msg in _initial) {
      _controller.add(msg);
    }
  }

  @override
  Future<void> disconnect() async {
    _controller.add(const ConnectionChanged(Disconnected()));
  }

  @override
  Future<void> resync() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
