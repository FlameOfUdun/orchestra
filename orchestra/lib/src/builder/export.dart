library;

part 'entity_definition.dart';
part 'system_definition.dart';
part 'orchestration_definition.dart';

final class Composer {
  Composer._();

  static OrchestrationDefinition createOrchestration() {
    return OrchestrationDefinition._();
  }
}
