import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import 'models/orchestrator_model.dart';
import 'visitors/modified_entity_collector.dart';

Set<VariableElement> extractModifiedEntities(
  List<FunctionBody> bodies,
  OrchestratorModel orchestrator,
) {
  final collector = ModifiedEntityCollector(orchestrator);
  for (final body in bodies) {
    body.accept(collector);
  }
  return collector.entities;
}

VariableElement? resolveToVariable(Element? element) {
  if (element is VariableElement) return element;
  if (element is PropertyAccessorElement)
    return element.variable as VariableElement?;
  return null;
}

VariableElement? extractVariable(Expression? expr) {
  return switch (expr) {
    SimpleIdentifier() => resolveToVariable(expr.element),
    PrefixedIdentifier() => resolveToVariable(expr.identifier.element),
    PropertyAccess() => extractVariable(expr.target),
    _ => null,
  };
}

ClassElement? extractClass(Expression? expr) {
  if (expr is SimpleIdentifier) {
    final element = expr.element;
    if (element is ClassElement) {
      return element;
    }
  }

  if (expr is PrefixedIdentifier) {
    final element = expr.identifier.element;
    if (element is ClassElement) {
      return element;
    }
  }

  if (expr is PropertyAccess) {
    final target = expr.target;
    return extractClass(target);
  }

  return null;
}

String capitalize(String input) {
  return input.isEmpty ? input : input[0].toUpperCase() + input.substring(1);
}

String rewriteExpression(Expression expr, OrchestratorModel orchestrator) {
  if (expr is NamedExpression) {
    return '${expr.name.label.name}: ${rewriteExpression(expr.expression, orchestrator)}';
  }

  if (expr is ThrowExpression) {
    return 'throw ${rewriteExpression(expr.expression, orchestrator)}';
  }

  if (expr is RethrowExpression) {
    return 'rethrow';
  }

  if (expr is IsExpression) {
    final target = rewriteExpression(expr.expression, orchestrator);
    final bang = expr.notOperator != null ? '!' : '';
    return '$target is$bang ${expr.type.toSource()}';
  }

  if (expr is AsExpression) {
    return '${rewriteExpression(expr.expression, orchestrator)} as ${expr.type.toSource()}';
  }

  if (expr is IndexExpression) {
    final target = rewriteExpression(expr.target!, orchestrator);
    final index = rewriteExpression(expr.index, orchestrator);
    return '$target[$index]';
  }

  if (expr is AssignmentExpression) {
    final lhs = rewriteExpression(expr.leftHandSide, orchestrator);
    final rhs = rewriteExpression(expr.rightHandSide, orchestrator);
    return '$lhs ${expr.operator.lexeme} $rhs';
  }

  if (expr is SimpleIdentifier) {
    final variable = resolveToVariable(expr.element);
    if (variable != null) {
      final entity = orchestrator.getEntity(variable);
      if (entity != null) {
        return 'get<${entity.entityType}>()';
      }
    }
    return expr.name;
  }

  if (expr is PropertyAccess) {
    final target = rewriteExpression(expr.target!, orchestrator);
    final op = expr.operator.lexeme; // ← '?.' or '.' or '?'
    final property = expr.propertyName.name;
    return '$target$op$property';
  }

  if (expr is PrefixedIdentifier) {
    final target = rewriteExpression(expr.prefix, orchestrator);
    final property = expr.identifier.name;
    return '$target.$property';
  }

  if (expr is PrefixExpression) {
    final operand = rewriteExpression(expr.operand, orchestrator);
    return '${expr.operator.lexeme}$operand';
  }

  if (expr is PostfixExpression) {
    final operand = rewriteExpression(expr.operand, orchestrator);
    return '$operand${expr.operator.lexeme}';
  }

  if (expr is AwaitExpression) {
    return 'await ${rewriteExpression(expr.expression, orchestrator)}';
  }

  if (expr is BinaryExpression) {
    final left = rewriteExpression(expr.leftOperand, orchestrator);
    final right = rewriteExpression(expr.rightOperand, orchestrator);

    return '$left ${expr.operator.lexeme} $right';
  }

  if (expr is MethodInvocation) {
    final typeArgs = expr.typeArguments?.toSource() ?? '';
    final args = expr.argumentList.arguments
        .map((a) => rewriteExpression(a, orchestrator))
        .join(', ');

    if (expr.target != null) {
      final target = rewriteExpression(expr.target as Expression, orchestrator);
      final op = expr.operator?.lexeme ?? '.'; // ← '?.' or '.'
      return '$target$op${expr.methodName.name}$typeArgs($args)';
    }

    return '${expr.methodName.name}$typeArgs($args)';
  }

  if (expr is ConditionalExpression) {
    final cond = rewriteExpression(expr.condition, orchestrator);
    final then = rewriteExpression(expr.thenExpression, orchestrator);
    final other = rewriteExpression(expr.elseExpression, orchestrator);
    return '$cond ? $then : $other';
  }

  if (expr is InstanceCreationExpression) {
    final kw = expr.keyword?.lexeme;
    final name = expr.constructorName.toSource();
    final args = expr.argumentList.arguments
        .map((a) => rewriteExpression(a, orchestrator))
        .join(', ');
    return kw != null ? '$kw $name($args)' : '$name($args)';
  }

  if (expr is FunctionExpressionInvocation) {
    final fn = rewriteExpression(expr.function, orchestrator);
    final args = expr.argumentList.arguments
        .map((a) => rewriteExpression(a, orchestrator))
        .join(', ');
    return '$fn($args)';
  }

  if (expr is ParenthesizedExpression) {
    return '(${rewriteExpression(expr.expression, orchestrator)})';
  }

  if (expr is FunctionExpression) {
    final params = expr.parameters?.toSource() ?? '()';
    final body = rewriteFunctionBody(expr.body, orchestrator, asClosure: true);
    return '$params $body';
  }

  if (expr is ListLiteral) {
    final typeArgs = expr.typeArguments?.toSource() ?? '';
    final elements = expr.elements
        .map((e) => _rewriteCollectionElement(e, orchestrator))
        .join(', ');
    final constKw = expr.constKeyword != null ? 'const ' : '';
    return '$constKw$typeArgs[$elements]';
  }

  if (expr is SetOrMapLiteral) {
    final typeArgs = expr.typeArguments?.toSource() ?? '';
    final elements = expr.elements
        .map((e) => _rewriteCollectionElement(e, orchestrator))
        .join(', ');
    final constKw = expr.constKeyword != null ? 'const ' : '';
    return '$constKw$typeArgs{$elements}';
  }

  if (expr is RecordLiteral) {
    final fields =
        expr.fields.map((f) => rewriteExpression(f, orchestrator)).join(', ');
    final constKw = expr.constKeyword != null ? 'const ' : '';
    return '$constKw($fields)';
  }

  if (expr is StringInterpolation) {
    final buffer = StringBuffer();
    for (final element in expr.elements) {
      if (element is InterpolationString) {
        buffer.write(element.contents.lexeme);
      } else if (element is InterpolationExpression) {
        final inner = rewriteExpression(element.expression, orchestrator);
        final hasBraces = element.leftBracket.lexeme == r'${';
        buffer.write(hasBraces ? '\${$inner}' : '\$$inner');
      }
    }
    return buffer.toString();
  }

  if (expr is CascadeExpression) {
    final target = rewriteExpression(expr.target, orchestrator);
    final sections = expr.cascadeSections
        .map((s) => rewriteExpression(s, orchestrator))
        .join();
    return '$target$sections';
  }

  if (expr is SwitchExpression) {
    final scrutinee = rewriteExpression(expr.expression, orchestrator);
    final buffer = StringBuffer('switch ($scrutinee) {\n');
    for (final c in expr.cases) {
      final pattern = c.guardedPattern.pattern.toSource();
      final whenClause = c.guardedPattern.whenClause;
      final guard = whenClause != null
          ? ' when ${rewriteExpression(whenClause.expression, orchestrator)}'
          : '';
      buffer.writeln(
          '  $pattern$guard => ${rewriteExpression(c.expression, orchestrator)},');
    }
    buffer.write('}');
    return buffer.toString();
  }

  return expr.toSource();
}

String _rewriteCollectionElement(
    CollectionElement element, OrchestratorModel orchestrator) {
  if (element is Expression) {
    return rewriteExpression(element, orchestrator);
  }
  if (element is MapLiteralEntry) {
    final key = rewriteExpression(element.key, orchestrator);
    final value = rewriteExpression(element.value, orchestrator);
    return '$key: $value';
  }
  if (element is SpreadElement) {
    final dots = element.spreadOperator.lexeme;
    return '$dots${rewriteExpression(element.expression, orchestrator)}';
  }
  if (element is IfElement) {
    final cond = rewriteExpression(element.expression, orchestrator);
    final then = _rewriteCollectionElement(element.thenElement, orchestrator);
    final elseElement = element.elseElement;
    final elsePart = elseElement != null
        ? ' else ${_rewriteCollectionElement(elseElement, orchestrator)}'
        : '';
    return 'if ($cond) $then$elsePart';
  }
  if (element is ForElement) {
    final body = _rewriteCollectionElement(element.body, orchestrator);
    final parts = element.forLoopParts;
    if (parts is ForEachPartsWithDeclaration) {
      return 'for (${parts.loopVariable.toSource()} in ${rewriteExpression(parts.iterable, orchestrator)}) $body';
    }
    if (parts is ForEachPartsWithIdentifier) {
      return 'for (${parts.identifier.toSource()} in ${rewriteExpression(parts.iterable, orchestrator)}) $body';
    }
    return 'for (${parts.toSource()}) $body';
  }
  return element.toSource();
}

String rewriteFunctionBody(
  FunctionBody body,
  OrchestratorModel orchestrator, {
  bool asClosure = false,
}) {
  final keyword = body.keyword?.lexeme;
  final star = body.star?.lexeme ?? '';
  final prefix = keyword == null ? '' : '$keyword$star ';

  if (body is ExpressionFunctionBody) {
    final expr = rewriteExpression(body.expression, orchestrator);
    return '$prefix=> $expr${asClosure ? '' : ';'}';
  }

  if (body is BlockFunctionBody) {
    return '$prefix${rewriteBlock(body.block, orchestrator)}';
  }

  return body.toSource();
}

String rewriteStatement(Statement stmt, OrchestratorModel orchestrator) {
  if (stmt is ExpressionStatement) {
    final expr = stmt.expression;

    if (expr is AssignmentExpression) {
      final lhs = expr.leftHandSide;
      String lhsRepl;
      if (lhs is SimpleIdentifier) {
        final variable = resolveToVariable(lhs.element);
        if (variable != null) {
          final ent = orchestrator.getEntity(variable);
          if (ent != null) {
            lhsRepl = 'get<${ent.entityType}>().value';
          } else {
            lhsRepl = rewriteExpression(lhs, orchestrator);
          }
        } else {
          lhsRepl = rewriteExpression(lhs, orchestrator);
        }
      } else {
        lhsRepl = rewriteExpression(lhs, orchestrator);
      }

      final rhs = rewriteExpression(expr.rightHandSide, orchestrator);
      final op = expr.operator.lexeme;
      return '$lhsRepl $op $rhs;';
    }

    if (expr is MethodInvocation && expr.target == null) {
      final variable = resolveToVariable(expr.methodName.element);
      if (variable != null) {
        final entity = orchestrator.getEntity(variable);
        if (entity != null) {
          final args = expr.argumentList.arguments;
          if (args.isEmpty) {
            return 'get<${entity.entityType}>().trigger();';
          } else {
            final transformedArgs =
                args.map((a) => rewriteExpression(a, orchestrator)).join(', ');
            return 'get<${entity.entityType}>().trigger($transformedArgs);';
          }
        }
      }
    }

    return '${rewriteExpression(expr, orchestrator)};';
  }

  if (stmt is SwitchStatement) {
    final expr = rewriteExpression(stmt.expression, orchestrator);
    final buffer = StringBuffer('switch ($expr) {\n');

    for (final member in stmt.members) {
      if (member is SwitchCase) {
        buffer.writeln(
            '  case ${rewriteExpression(member.expression, orchestrator)}:');
      } else if (member is SwitchPatternCase) {
        final pattern = member.guardedPattern.pattern.toSource();
        final whenClause = member.guardedPattern.whenClause;
        final guard = whenClause != null
            ? ' when ${rewriteExpression(whenClause.expression, orchestrator)}'
            : '';
        buffer.writeln('  case $pattern$guard:');
      } else if (member is SwitchDefault) {
        buffer.writeln('  default:');
      }
      for (final s in member.statements) {
        buffer.writeln('    ${rewriteStatement(s, orchestrator)}');
      }
    }

    buffer.write('}');
    return buffer.toString();
  }

  if (stmt is LabeledStatement) {
    final labels = stmt.labels.map((l) => '${l.label.name}:').join(' ');
    return '$labels ${rewriteStatement(stmt.statement, orchestrator)}';
  }

  if (stmt is ReturnStatement) {
    if (stmt.expression == null) return 'return;';
    return 'return ${rewriteExpression(stmt.expression!, orchestrator)};';
  }

  if (stmt is VariableDeclarationStatement) {
    final declList = stmt.variables;
    final kw = declList.keyword?.lexeme;
    final typeSrc = declList.type?.toSource();
    final header = kw ?? typeSrc ?? 'var';

    final parts = <String>[];
    for (final decl in declList.variables) {
      final name = decl.name.lexeme;
      final init = decl.initializer;
      if (init != null) {
        parts.add('$name = ${rewriteExpression(init, orchestrator)}');
      } else {
        parts.add(name);
      }
    }

    return '$header ${parts.join(', ')};';
  }

  if (stmt is TryStatement) {
    final buffer = StringBuffer('try ');
    buffer.write(rewriteBlock(stmt.body, orchestrator));

    for (final clause in stmt.catchClauses) {
      if (clause.exceptionType != null) {
        buffer.write(' on ${clause.exceptionType!.toSource()}');
      }
      if (clause.catchKeyword != null) {
        final ex = clause.exceptionParameter?.name.lexeme ?? '_';
        final st = clause.stackTraceParameter;
        buffer.write(
            st != null ? ' catch ($ex, ${st.name.lexeme})' : ' catch ($ex)');
      }
      buffer.write(' ');
      buffer.write(rewriteBlock(clause.body, orchestrator));
    }

    if (stmt.finallyBlock != null) {
      buffer.write(' finally ');
      buffer.write(rewriteBlock(stmt.finallyBlock!, orchestrator));
    }
    return buffer.toString();
  }

  if (stmt is IfStatement) {
    final cond = rewriteExpression(stmt.expression, orchestrator);
    final then = rewriteStatement(stmt.thenStatement, orchestrator);
    final buffer = StringBuffer('if ($cond) $then');
    if (stmt.elseStatement != null) {
      buffer.write(
          ' else ${rewriteStatement(stmt.elseStatement!, orchestrator)}');
    }
    return buffer.toString();
  }

  if (stmt is Block) {
    return rewriteBlock(stmt, orchestrator);
  }

  if (stmt is WhileStatement) {
    return 'while (${rewriteExpression(stmt.condition, orchestrator)}) '
        '${rewriteStatement(stmt.body, orchestrator)}';
  }

  if (stmt is DoStatement) {
    return 'do ${rewriteStatement(stmt.body, orchestrator)} '
        'while (${rewriteExpression(stmt.condition, orchestrator)});';
  }

  if (stmt is ForStatement) {
    final body = rewriteStatement(stmt.body, orchestrator);
    final parts = stmt.forLoopParts;
    if (parts is ForEachPartsWithDeclaration) {
      return 'for (${parts.loopVariable.toSource()} in '
          '${rewriteExpression(parts.iterable, orchestrator)}) $body';
    }
    if (parts is ForEachPartsWithIdentifier) {
      return 'for (${parts.identifier.toSource()} in '
          '${rewriteExpression(parts.iterable, orchestrator)}) $body';
    }
    return 'for (${parts.toSource()}) $body';
  }

  if (stmt is YieldStatement) {
    final star = stmt.star?.lexeme ?? '';
    return 'yield$star ${rewriteExpression(stmt.expression, orchestrator)};';
  }

  if (stmt is BreakStatement || stmt is ContinueStatement) {
    return stmt.toSource();
  }

  if (stmt is AssertStatement) {
    final cond = rewriteExpression(stmt.condition, orchestrator);
    final message = stmt.message;
    if (message != null) {
      return 'assert($cond, ${rewriteExpression(message, orchestrator)});';
    }
    return 'assert($cond);';
  }

  if (stmt is FunctionDeclarationStatement) {
    final decl = stmt.functionDeclaration;
    final ret = decl.returnType?.toSource();
    final hName = decl.name.lexeme;
    final params = decl.functionExpression.parameters?.toSource() ?? '()';
    final body =
        rewriteFunctionBody(decl.functionExpression.body, orchestrator);
    return '${ret != null ? '$ret ' : ''}$hName$params $body';
  }

  return stmt.toSource();
}

String rewriteBlock(Block block, OrchestratorModel orchestrator) {
  final buffer = StringBuffer('{\n');
  for (final stmt in block.statements) {
    buffer.writeln('  ${rewriteStatement(stmt, orchestrator)}');
  }
  buffer.write('}');
  return buffer.toString();
}
