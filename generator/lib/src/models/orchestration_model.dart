import 'package:analyzer/dart/element/element.dart';

import '../helpers.dart';
import 'entity_model.dart';
import 'orchestrator_model.dart';
import 'system_model.dart';

final class OrchestrationModel {
  final String name;
  late final String ecsType;
  final Map<VariableElement, EntityModel> entities = {};
  final Set<SystemModel> systems = {};
  final VariableElement element;

  OrchestratorModel? manager;

  OrchestrationModel({
    required this.name,
    required this.element,
  }) {
    final capitalized = capitalize(name);
    ecsType = capitalized.endsWith("Orchestration")
        ? capitalized
        : "${capitalized}Orchestration";
  }

  EntityModel? getEntity(VariableElement element) {
    final direct = entities[element];
    if (direct != null) return direct;

    final path = element.firstFragment.libraryFragment?.source.fullName ?? '';
    final name = element.name ?? '';
    if (path.isEmpty || name.isEmpty) return null;

    for (final entry in entities.entries) {
      final k = entry.key;
      if (k.name == name &&
          k.firstFragment.libraryFragment?.source.fullName == path) {
        return entry.value;
      }
    }

    return null;
  }

  void addEntity(EntityModel entity) {
    entities[entity.element] = entity;
    entity.orchestration = this;
  }

  void addSystem(SystemModel system) {
    systems.add(system);
    system.orchestration = this;
  }

  String generate() {
    final buffer = StringBuffer();

    final components = entities.values.whereType<ComponentModel>();
    for (final component in components) {
      buffer.writeln(component.generate());
      buffer.writeln();
    }

    final events = entities.values.whereType<EventModel>();
    for (final event in events) {
      buffer.writeln(event.generate());
      buffer.writeln();
    }

    final dataEvents = entities.values.whereType<DataEventModel>();
    for (final event in dataEvents) {
      buffer.writeln(event.generate());
      buffer.writeln();
    }

    final dependencies = entities.values.whereType<DependencyModel>();
    for (final dependency in dependencies) {
      buffer.writeln(dependency.generate());
      buffer.writeln();
    }

    for (final system in systems) {
      buffer.writeln(system.generate());
      buffer.writeln();
    }

    buffer.writeln('final class $ecsType extends Orchestration {');
    buffer.writeln('  $ecsType() {');
    for (final component in components) {
      buffer.writeln('    add(${component.entityType}());');
    }
    for (final event in events) {
      buffer.writeln('    add(${event.entityType}());');
    }
    for (final event in dataEvents) {
      buffer.writeln('    add(${event.entityType}());');
    }
    for (final dependency in dependencies) {
      buffer.writeln('    add(${dependency.entityType}());');
    }
    for (final system in systems) {
      buffer.writeln('    add(${system.systemType}());');
    }
    buffer.writeln('  }');
    buffer.write("}");

    return buffer.toString();
  }
}
