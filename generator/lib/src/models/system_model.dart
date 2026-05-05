import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import '../helpers.dart';
import 'orchestration_model.dart';
import 'orchestrator_model.dart';

sealed class SystemModel {
  final String name;
  late final String systemType;
  final List<FunctionDeclaration> helpers;

  OrchestrationModel? orchestration;

  SystemModel({
    required this.name,
    required String suffix,
    this.helpers = const [],
  }) {
    final capitalized = capitalize(name);
    systemType = capitalized.endsWith(suffix) ? capitalized : '$capitalized$suffix';
  }

  String generate();

  List<FunctionBody> get _bodiesToScan;

  void _writeInteractsWith(StringBuffer buffer, OrchestratorModel orchestrator) {
    final modified = extractModifiedEntities(_bodiesToScan, orchestrator).map((v) => orchestrator.getEntity(v)?.entityType).whereType<String>().toList()..sort();

    if (modified.isEmpty) return;

    buffer.writeln('  @override');
    buffer.writeln('  Set<Type> get interactsWith {');
    buffer.writeln('    return const {${modified.join(', ')}};');
    buffer.writeln('  }');
    buffer.writeln();
  }

  void _writeGuard(StringBuffer buffer, String guardName, FunctionBody? guard, OrchestratorModel orchestrator) {
    if (guard == null) return;
    buffer.writeln('  @override');
    buffer.writeln('  bool get $guardName ${rewriteFunctionBody(guard, orchestrator)}');
  }

  void _writeHelpers(StringBuffer buffer, OrchestratorModel orchestrator) {
    for (final helper in helpers) {
      buffer.writeln();
      final ret = helper.returnType?.toSource();
      final hName = helper.name.lexeme;
      final params = helper.functionExpression.parameters?.toSource() ?? '()';
      final body = rewriteFunctionBody(helper.functionExpression.body, orchestrator);
      buffer.write('  ${ret != null ? '$ret ' : ''}$hName$params $body');
    }
  }
}

final class ReactiveSystemModel extends SystemModel {
  final Set<VariableElement> reactsTo;
  final FunctionBody? reactsIf;
  final FunctionBody react;

  ReactiveSystemModel({
    required super.name,
    required this.reactsTo,
    required this.react,
    this.reactsIf,
    super.helpers,
  }) : super(suffix: 'ReactiveSystem');

  @override
  List<FunctionBody> get _bodiesToScan {
    return [
      react,
      ...helpers.map((h) => h.functionExpression.body),
    ];
  }

  @override
  String generate() {
    final manager = orchestration!.manager!;

    final reactsToTokens = (reactsTo.map((e) {
      final resolved = manager.getEntity(e)?.entityType;
      if (resolved != null) return resolved;
      final fallback = e.name;
      if (fallback == null) {
        throw StateError('ReactiveSystem "$name": cannot resolve a reactsTo entry to a known entity.');
      }
      return fallback;
    }).toList()..sort()).join(', ');

    final buffer = StringBuffer('final class $systemType extends ReactiveSystem {\n');
    buffer.writeln('  @override');
    buffer.writeln('  Set<Type> get reactsTo {');
    buffer.writeln('    return const {$reactsToTokens};');
    buffer.writeln('  }');
    buffer.writeln();
    _writeInteractsWith(buffer, manager);
    _writeGuard(buffer, 'reactsIf', reactsIf, manager);
    buffer.writeln('  @override');
    buffer.write('  void react() ${rewriteFunctionBody(react, manager)}');
    _writeHelpers(buffer, manager);
    buffer.write('\n}');
    return buffer.toString();
  }
}

final class ExecuteSystemModel extends SystemModel {
  final FunctionBody execute;
  final FunctionBody? executesIf;

  ExecuteSystemModel({
    required super.name,
    required this.execute,
    this.executesIf,
    super.helpers,
  }) : super(suffix: 'ExecuteSystem');

  @override
  List<FunctionBody> get _bodiesToScan => [
        execute,
        ...helpers.map((h) => h.functionExpression.body),
      ];

  @override
  String generate() {
    final manager = orchestration!.manager!;

    final buffer = StringBuffer('final class $systemType extends ExecuteSystem {\n');
    _writeInteractsWith(buffer, manager);
    _writeGuard(buffer, 'executesIf', executesIf, manager);
    buffer.writeln('  @override');
    buffer.write('  void execute(Duration elapsed) ${rewriteFunctionBody(execute, manager)}');
    _writeHelpers(buffer, manager);
    buffer.write('\n}');
    return buffer.toString();
  }
}

final class CleanupSystemModel extends SystemModel {
  final FunctionBody cleanup;
  final FunctionBody? cleansIf;

  CleanupSystemModel({
    required super.name,
    required this.cleanup,
    this.cleansIf,
    super.helpers,
  }) : super(suffix: 'CleanupSystem');

  @override
  List<FunctionBody> get _bodiesToScan {
    return [
      cleanup,
      ...helpers.map((h) => h.functionExpression.body),
    ];
  }

  @override
  String generate() {
    final manager = orchestration!.manager!;

    final buffer = StringBuffer('final class $systemType extends CleanupSystem {\n');
    _writeInteractsWith(buffer, manager);
    _writeGuard(buffer, 'cleansIf', cleansIf, manager);
    buffer.writeln('  @override');
    buffer.write('  void cleanup() ${rewriteFunctionBody(cleanup, manager)}');
    _writeHelpers(buffer, manager);
    buffer.write('\n}');
    return buffer.toString();
  }
}

final class TeardownSystemModel extends SystemModel {
  final FunctionBody teardown;
  final FunctionBody? teardownsIf;

  TeardownSystemModel({
    required super.name,
    required this.teardown,
    this.teardownsIf,
    super.helpers,
  }) : super(suffix: 'TeardownSystem');

  @override
  List<FunctionBody> get _bodiesToScan {
    return [
      teardown,
      ...helpers.map((h) => h.functionExpression.body),
    ];
  }

  @override
  String generate() {
    final manager = orchestration!.manager!;

    final buffer = StringBuffer('final class $systemType extends TeardownSystem {\n');
    _writeInteractsWith(buffer, manager);
    _writeGuard(buffer, 'teardownsIf', teardownsIf, manager);
    buffer.writeln('  @override');
    buffer.write('  void teardown() ${rewriteFunctionBody(teardown, manager)}');
    _writeHelpers(buffer, manager);
    buffer.write('\n}');
    return buffer.toString();
  }
}

final class InitializeSystemModel extends SystemModel {
  final FunctionBody initialize;

  InitializeSystemModel({
    required super.name,
    required this.initialize,
    super.helpers,
  }) : super(suffix: 'InitializeSystem');

  @override
  List<FunctionBody> get _bodiesToScan {
    return [
      initialize,
      ...helpers.map((h) => h.functionExpression.body),
    ];
  }

  @override
  String generate() {
    final manager = orchestration!.manager!;

    final buffer = StringBuffer('final class $systemType extends InitializeSystem {\n');
    _writeInteractsWith(buffer, manager);
    buffer.writeln('  @override');
    buffer.write('  void initialize() ${rewriteFunctionBody(initialize, manager)}');
    _writeHelpers(buffer, manager);
    buffer.write('\n}');
    return buffer.toString();
  }
}
