final class RuntimeOrchestrator {
  final String id;
  final String name;
  final bool isActive;
  final List<String> orchestrationIds;

  const RuntimeOrchestrator({
    required this.id,
    required this.name,
    required this.isActive,
    this.orchestrationIds = const [],
  });

  RuntimeOrchestrator copyWith({
    String? name,
    bool? isActive,
    List<String>? orchestrationIds,
  }) {
    return RuntimeOrchestrator(
      id: id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      orchestrationIds: orchestrationIds ?? this.orchestrationIds,
    );
  }
}
