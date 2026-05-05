enum TopologyNodeKind {
  component,
  event,
  dataEvent,
  dependency,
  system,
  lifecycle,
}

final class TopologyNode {
  final String id;
  final String name;
  final TopologyNodeKind kind;
  final String? orchestrationId;
  final String? subtitle;

  const TopologyNode({
    required this.id,
    required this.name,
    required this.kind,
    this.orchestrationId,
    this.subtitle,
  });
}
