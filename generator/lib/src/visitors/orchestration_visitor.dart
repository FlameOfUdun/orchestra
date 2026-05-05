import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../helpers.dart';
import '../models/orchestration_model.dart';
import '../models/orchestrator_model.dart';

final class OrchestrationVisitor extends RecursiveAstVisitor<void> {
  final OrchestratorModel orchestrator;

  OrchestrationVisitor(this.orchestrator);

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final init = node.initializer;

    if (init is! MethodInvocation) return;
    if (init.methodName.name != 'createOrchestration') return;

    final target = init.target;
    final classElement = extractClass(target);
    if (classElement == null || classElement.name != 'Composer') {
      return;
    }

    final element = node.declaredFragment?.element;
    if (element is! VariableElement) return;

    orchestrator.addOrchestration(OrchestrationModel(name: node.name.lexeme, element: element));
  }
}
