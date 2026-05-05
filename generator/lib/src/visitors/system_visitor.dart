import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../helpers.dart';
import '../models/orchestrator_model.dart';
import '../models/system_model.dart';

final class SystemVisitor extends RecursiveAstVisitor<void> {
  final OrchestratorModel orchestrator;
  final Map<String, FunctionDeclaration> _functions = {};

  SystemVisitor(this.orchestrator);

  static const _supportedMethods = {
    'addReactiveSystem',
    'addExecuteSystem',
    'addCleanupSystem',
    'addTeardownSystem',
    'addInitializeSystem',
  };

  @override
  void visitCompilationUnit(CompilationUnit node) {
    for (final decl in node.declarations) {
      if (decl is FunctionDeclaration) {
        _functions[decl.name.lexeme] = decl;
      }
    }
    super.visitCompilationUnit(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element is! VariableElement) {
      super.visitVariableDeclaration(node);
      return;
    }

    final init = node.initializer;
    if (init is! MethodInvocation ||
        !_supportedMethods.contains(init.methodName.name)) {
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

    final system = _buildSystem(node.name.lexeme, element, init);
    if (system != null) {
      system.orchestration = orchestration;
      orchestration.addSystem(system);
    }

    super.visitVariableDeclaration(node);
  }

  SystemModel? _buildSystem(
    String name,
    VariableElement element,
    MethodInvocation init,
  ) {
    return switch (init.methodName.name) {
      'addReactiveSystem' => _handleReactiveSystem(name, element, init),
      'addExecuteSystem' => _handleExecuteSystem(name, element, init),
      'addCleanupSystem' => _handleCleanupSystem(name, element, init),
      'addTeardownSystem' => _handleTeardownSystem(name, element, init),
      'addInitializeSystem' => _handleInitializeSystem(name, element, init),
      _ => null,
    };
  }

  ReactiveSystemModel _handleReactiveSystem(
    String name,
    VariableElement element,
    MethodInvocation init,
  ) {
    final args = _namedArgMap(init);

    final reactExpr = args['react'];
    if (reactExpr is! FunctionExpression) {
      throw StateError(
        'addReactiveSystem("$name"): "react" must be a function literal.',
      );
    }

    final reactsIfExpr = args['reactsIf'];

    return ReactiveSystemModel(
      name: name,
      reactsTo: _extractReactsTo(args['reactsTo']),
      react: reactExpr.body,
      reactsIf: reactsIfExpr is FunctionExpression ? reactsIfExpr.body : null,
      helpers: [
        ..._resolveHelpers(reactExpr.body),
        if (reactsIfExpr is FunctionExpression)
          ..._resolveHelpers(reactsIfExpr.body),
      ],
    );
  }

  ExecuteSystemModel? _handleExecuteSystem(
    String name,
    VariableElement element,
    MethodInvocation init,
  ) {
    final args = _namedArgMap(init);

    final executeExpr = args['execute'];
    if (executeExpr is! FunctionExpression) {
      throw StateError(
        'addExecuteSystem("$name"): "execute" must be a function literal.',
      );
    }

    final executesIfExpr = args['executesIf'];

    return ExecuteSystemModel(
      name: name,
      execute: executeExpr.body,
      executesIf:
          executesIfExpr is FunctionExpression ? executesIfExpr.body : null,
      helpers: [
        ..._resolveHelpers(executeExpr.body),
        if (executesIfExpr is FunctionExpression)
          ..._resolveHelpers(executesIfExpr.body),
      ],
    );
  }

  CleanupSystemModel? _handleCleanupSystem(
    String name,
    VariableElement element,
    MethodInvocation init,
  ) {
    final args = _namedArgMap(init);

    final cleanupExpr = args['cleanup'];
    if (cleanupExpr is! FunctionExpression) {
      throw StateError(
        'addCleanupSystem("$name"): "cleanup" must be a function literal.',
      );
    }

    final cleansIfExpr = args['cleansIf'];

    return CleanupSystemModel(
      name: name,
      cleanup: cleanupExpr.body,
      cleansIf: cleansIfExpr is FunctionExpression ? cleansIfExpr.body : null,
      helpers: [
        ..._resolveHelpers(cleanupExpr.body),
        if (cleansIfExpr is FunctionExpression)
          ..._resolveHelpers(cleansIfExpr.body),
      ],
    );
  }

  TeardownSystemModel? _handleTeardownSystem(
    String name,
    VariableElement element,
    MethodInvocation init,
  ) {
    final args = _namedArgMap(init);

    final teardownExpr = args['teardown'];
    if (teardownExpr is! FunctionExpression) {
      throw StateError(
        'addTeardownSystem("$name"): "teardown" must be a function literal.',
      );
    }

    final teardownsIfExpr = args['teardownsIf'];

    return TeardownSystemModel(
      name: name,
      teardown: teardownExpr.body,
      teardownsIf:
          teardownsIfExpr is FunctionExpression ? teardownsIfExpr.body : null,
      helpers: [
        ..._resolveHelpers(teardownExpr.body),
        if (teardownsIfExpr is FunctionExpression)
          ..._resolveHelpers(teardownsIfExpr.body),
      ],
    );
  }

  InitializeSystemModel? _handleInitializeSystem(
    String name,
    VariableElement element,
    MethodInvocation init,
  ) {
    final args = _namedArgMap(init);

    final initializeExpr = args['initialize'];
    if (initializeExpr is! FunctionExpression) {
      throw StateError(
        'addInitializeSystem("$name"): "initialize" must be a function literal.',
      );
    }

    return InitializeSystemModel(
      name: name,
      initialize: initializeExpr.body,
      helpers: _resolveHelpers(initializeExpr.body),
    );
  }

  List<FunctionDeclaration> _resolveHelpers(FunctionBody body) {
    final local = _extractLocalHelpers(body);
    final resolved = <String, FunctionDeclaration>{};
    final queue = <FunctionBody>[body];

    while (queue.isNotEmpty) {
      final current = queue.removeLast();

      final referenced = <String>{};
      current.accept(_TopLevelFunctionRefCollector(_functions, referenced));

      for (final name in referenced) {
        if (!resolved.containsKey(name)) {
          final decl = _functions[name]!;
          resolved[name] = decl;
          queue.add(decl.functionExpression.body);
        }
      }
    }

    return [...local, ...resolved.values];
  }

  Map<String, Expression> _namedArgMap(MethodInvocation init) {
    final map = <String, Expression>{};
    for (final arg in init.argumentList.arguments) {
      if (arg is NamedExpression) {
        map[arg.name.label.name] = arg.expression;
      }
    }
    return map;
  }

  Set<VariableElement> _extractReactsTo(Expression? expr) {
    if (expr == null) return {};
    final elements = <VariableElement>{};

    final collectionElements = switch (expr) {
      SetOrMapLiteral() => expr.elements,
      ListLiteral() => expr.elements,
      _ => null,
    };

    if (collectionElements != null) {
      for (final el in collectionElements) {
        final variable = switch (el) {
          SimpleIdentifier() => resolveToVariable(el.element),
          PrefixedIdentifier() => resolveToVariable(el.identifier.element),
          _ => null,
        };
        if (variable != null) elements.add(variable);
      }
    } else {
      final v = extractVariable(expr);
      if (v != null) elements.add(v);
    }

    return elements;
  }

  List<FunctionDeclaration> _extractLocalHelpers(FunctionBody body) {
    if (body is! BlockFunctionBody) return const [];
    return body.block.statements
        .whereType<FunctionDeclarationStatement>()
        .map((s) => s.functionDeclaration)
        .toList();
  }
}

final class _TopLevelFunctionRefCollector extends RecursiveAstVisitor<void> {
  final Map<String, FunctionDeclaration> functions;
  final Set<String> names;

  _TopLevelFunctionRefCollector(this.functions, this.names);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) {
      _addIfTopLevel(node.methodName);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.inDeclarationContext()) return;
    final parent = node.parent;
    if (parent is MethodInvocation && identical(parent.methodName, node)) {
      return;
    }
    if (parent is PrefixedIdentifier && identical(parent.identifier, node)) {
      return;
    }
    if (parent is PropertyAccess && identical(parent.propertyName, node)) {
      return;
    }
    _addIfTopLevel(node);
  }

  void _addIfTopLevel(SimpleIdentifier id) {
    final element = id.element;
    if (element is! ExecutableElement) return;
    if (element.enclosingElement is! LibraryElement) return;
    final name = id.name;
    if (functions.containsKey(name)) {
      names.add(name);
    }
  }
}
