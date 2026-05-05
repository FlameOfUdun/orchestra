final class RuntimeOrchestration {
  final String id;
  final String name;
  final String orchestratorId;
  final List<String> elementIds;
  final List<String> systemIds;

  const RuntimeOrchestration({
    required this.id,
    required this.name,
    required this.orchestratorId,
    this.elementIds = const [],
    this.systemIds = const [],
  });

  RuntimeOrchestration copyWith({
    String? name,
    String? orchestratorId,
    List<String>? elementIds,
    List<String>? systemIds,
  }) {
    return RuntimeOrchestration(
      id: id,
      name: name ?? this.name,
      orchestratorId: orchestratorId ?? this.orchestratorId,
      elementIds: elementIds ?? this.elementIds,
      systemIds: systemIds ?? this.systemIds,
    );
  }
}
