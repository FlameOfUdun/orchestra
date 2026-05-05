import 'dart:async';
import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';

import '../models/orchestrator_model.dart';
import '../visitors/entity_visitor.dart';
import '../visitors/orchestration_visitor.dart';
import '../visitors/system_visitor.dart';

final class OrchestrationBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.dart': ['.g.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;

    if (!await buildStep.resolver.isLibrary(inputId)) return;

    final library = await buildStep.resolver.libraryFor(inputId);

    final fragmentUnit = await buildStep.resolver.astNodeFor(library.firstFragment, resolve: false) as CompilationUnit?;
    final hasOrchestrationPart = fragmentUnit?.directives.whereType<PartDirective>().any((d) => d.uri.stringValue?.endsWith('.g.dart') ?? false) ?? false;
    if (!hasOrchestrationPart) return;

    final orchestrator = OrchestratorModel();

    await _scanImports(library, orchestrator, buildStep);

    final importedKeys = orchestrator.orchestrations.keys.toSet();

    final unit = await buildStep.resolver.astNodeFor(
      library.firstFragment,
      resolve: true,
    ) as CompilationUnit?;
    if (unit == null) return;

    unit.accept(OrchestrationVisitor(orchestrator));
    unit.accept(EntityVisitor(orchestrator));
    unit.accept(SystemVisitor(orchestrator));

    final localOrchestrations = orchestrator.orchestrations.entries.where((e) => !importedKeys.contains(e.key)).map((e) => e.value).toList();

    if (localOrchestrations.isEmpty) return;
    if (localOrchestrations.length > 1) {
      log.warning('Expected exactly one orchestration per file in ${inputId.path}');
      return;
    }

    final buffer = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln()
      ..writeln("part of '${inputId.pathSegments.last}';")
      ..writeln();

    for (final orchestration in localOrchestrations) {
      buffer
        ..writeln(orchestration.generate())
        ..writeln();
    }

    final formatted = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion, pageWidth: 120).format(buffer.toString());

    await buildStep.writeAsString(inputId.changeExtension('.g.dart'), formatted);
  }

  Future<void> _scanImports(LibraryElement root, OrchestratorModel orchestrator, BuildStep buildStep) async {
    final visited = <LibraryElement>{root};
    final queue = Queue<LibraryElement>();

    for (final import in root.firstFragment.libraryImports) {
      final lib = import.importedLibrary;
      if (lib != null && !lib.isInSdk) queue.add(lib);
    }

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (!visited.add(current)) continue;

      for (final import in current.firstFragment.libraryImports) {
        final next = import.importedLibrary;
        if (next != null && !next.isInSdk && !visited.contains(next)) {
          queue.add(next);
        }
      }

      if (!_mightDeclareOrchestration(current)) continue;

      final importedUnit = await buildStep.resolver.astNodeFor(
        current.firstFragment,
        resolve: true,
      ) as CompilationUnit?;

      if (importedUnit != null) {
        importedUnit.accept(OrchestrationVisitor(orchestrator));
        importedUnit.accept(EntityVisitor(orchestrator));
      }
    }
  }

  bool _mightDeclareOrchestration(LibraryElement library) {
    final source = library.firstFragment.source.contents.data;
    return source.contains('createOrchestration');
  }
}
