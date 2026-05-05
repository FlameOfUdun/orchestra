import 'package:analyzer/dart/element/element.dart';

import 'entity_model.dart';
import 'orchestration_model.dart';

final class OrchestratorModel {
  final Map<VariableElement, OrchestrationModel> orchestrations = {};

  void addOrchestration(OrchestrationModel orchestration) {
    orchestrations[orchestration.element] = orchestration;
    orchestration.manager = this;
  }

  OrchestrationModel? getOrchestration(VariableElement element) {
    final direct = orchestrations[element];
    if (direct != null) return direct;

    final path = element.firstFragment.libraryFragment?.source.fullName ?? '';
    final name = element.name ?? '';
    if (path.isEmpty || name.isEmpty) return null;

    for (final entry in orchestrations.entries) {
      final k = entry.key;
      if (k.name == name &&
          k.firstFragment.libraryFragment?.source.fullName == path) {
        return entry.value;
      }
    }

    return null;
  }

  EntityModel? getEntity(VariableElement element) {
    for (final orchestration in orchestrations.values) {
      final entity = orchestration.getEntity(element);
      if (entity != null) return entity;
    }
    return null;
  }
}
