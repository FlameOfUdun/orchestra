import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../helpers.dart';
import '../models/entity_model.dart';
import '../models/orchestrator_model.dart';

final class EntityVisitor extends RecursiveAstVisitor<void> {
  final OrchestratorModel orchestrator;

  EntityVisitor(this.orchestrator);

  static const _supportedMethods = {
    'addComponent',
    'addEvent',
    'addDataEvent',
    'addDependency',
  };

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element is! VariableElement) {
      super.visitVariableDeclaration(node);
      return;
    }

    final init = node.initializer;
    if (init is! MethodInvocation || !_supportedMethods.contains(init.methodName.name)) {
      super.visitVariableDeclaration(node);
      return;
    }

    final featureElement = extractVariable(init.target);
    if (featureElement == null) {
      super.visitVariableDeclaration(node);
      return;
    }

    final orchestration = orchestrator.getOrchestration(featureElement);
    if (orchestration == null) {
      super.visitVariableDeclaration(node);
      return;
    }

    final entity = _buildEntity(node.name.lexeme, element, init);
    if (entity != null) {
      orchestration.addEntity(entity);
    }

    super.visitVariableDeclaration(node);
  }

  EntityModel? _buildEntity(String name, VariableElement element, MethodInvocation init) {
    return switch (init.methodName.name) {
      'addComponent' => _buildComponent(name, element, init),
      'addEvent' => _buildEvent(name, element),
      'addDataEvent' => _buildDataEvent(name, element, init),
      'addDependency' => _buildDependency(name, element, init),
      _ => null,
    };
  }

  EventModel _buildEvent(String name, VariableElement element) {
    return EventModel(name: name, element: element);
  }

  ComponentModel _buildComponent(String name, VariableElement element, MethodInvocation init) {
    final type = _resolveTypeString(name, 'addComponent', element, init);
    final args = init.argumentList.arguments;
    if (args.isEmpty) {
      throw StateError('addComponent("$name"): an initial value is required.');
    }
    return ComponentModel(
      name: name,
      element: element,
      type: type,
      value: args.first.toSource(),
    );
  }

  DataEventModel _buildDataEvent(String name, VariableElement element, MethodInvocation init) {
    final type = _resolveTypeString(name, 'addDataEvent', element, init);
    return DataEventModel(
      name: name,
      element: element,
      type: type,
    );
  }

  DependencyModel _buildDependency(String name, VariableElement element, MethodInvocation init) {
    final type = _resolveTypeString(name, 'addDependency', element, init);
    final args = init.argumentList.arguments;
    if (args.isEmpty) {
      throw StateError('addDependency("$name"): an initial value is required.');
    }
    return DependencyModel(
      name: name,
      element: element,
      type: type,
      value: args.first.toSource(),
    );
  }

  String _resolveTypeString(String name, String method, VariableElement element, MethodInvocation init) {
    final explicitArgs = init.typeArguments?.arguments;
    if (explicitArgs != null && explicitArgs.isNotEmpty) {
      final resolved = explicitArgs.first.type?.getDisplayString();
      if (resolved != null) return resolved;
    }

    final varType = element.type;
    if (varType is ParameterizedType && varType.typeArguments.isNotEmpty) {
      final resolved = varType.typeArguments.first.getDisplayString();
      return resolved;
    }

    throw StateError('$method("$name"): cannot infer type — supply an explicit type argument.');
  }
}
