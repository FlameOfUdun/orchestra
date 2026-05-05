final class SystemFiring {
  final String systemId;
  final String? triggerEntityId;
  final int firedAtMicros;
  final int durationMicros;
  final bool succeeded;

  const SystemFiring({
    required this.systemId,
    required this.triggerEntityId,
    required this.firedAtMicros,
    required this.durationMicros,
    required this.succeeded,
  });
}
