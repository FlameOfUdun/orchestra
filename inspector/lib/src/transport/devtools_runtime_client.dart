import 'inspector_client.dart';

export 'inspector_client.dart';

/// Alias to the DevTools-backed runtime client.
/// Use [DevToolsRuntimeClient] in new code; [DevToolsInspectorClient] is the
/// implementation behind this alias until the rename is complete.
typedef DevToolsRuntimeClient = DevToolsInspectorClient;
