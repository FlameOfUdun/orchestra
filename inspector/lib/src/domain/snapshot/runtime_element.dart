import 'package:orchestra/inspector_export.dart';

final class RuntimeElement {
  final String id;
  final String name;
  final EntityKindDto kind;
  final String typeName;
  final String orchestrationId;
  final JsonValueDto? value;
  final JsonValueDto? previous;
  final int? updatedAtMicros;
  final int updateCount;

  const RuntimeElement({
    required this.id,
    required this.name,
    required this.kind,
    required this.typeName,
    required this.orchestrationId,
    this.value,
    this.previous,
    this.updatedAtMicros,
    this.updateCount = 0,
  });

  RuntimeElement copyWith({
    String? name,
    EntityKindDto? kind,
    String? typeName,
    String? orchestrationId,
    JsonValueDto? value,
    JsonValueDto? previous,
    int? updatedAtMicros,
    int? updateCount,
  }) {
    return RuntimeElement(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      typeName: typeName ?? this.typeName,
      orchestrationId: orchestrationId ?? this.orchestrationId,
      value: value ?? this.value,
      previous: previous ?? this.previous,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      updateCount: updateCount ?? this.updateCount,
    );
  }

  factory RuntimeElement.fromDto(EntityDto dto) {
    return RuntimeElement(
      id: dto.id,
      name: dto.name,
      kind: dto.kind,
      typeName: dto.typeName,
      orchestrationId: dto.orchestrationId,
      value: dto.value,
      previous: dto.previous,
      updatedAtMicros: dto.updatedAtMicros,
    );
  }
}
