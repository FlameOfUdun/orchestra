# Orchestra Inspector

A small DevTools inspector project that complements the `orchestra` core package. It builds a DevTools extension containing visual tools for inspecting features, entities, events, and system interactions at runtime.

## Purpose

- Provide a visual debugging surface for Orchestra-based apps
- Ship a DevTools extension that can be loaded by the `orchestra` package during development

## Prerequisites

- Dart & Flutter SDK installed
- `devtools_extensions` package available (used by the build scripts)

## Build & Install (development)

Build the DevTools extension and copy it into the `orchestra` package extension folder:

```bash
dart run devtools_extensions build_and_copy --source=. --dest=../orchestra/extension/devtools
```

Validate the extension package (run from this folder):

```bash
dart run devtools_extensions validate --package=../orchestra
```

After copying, run your Flutter app that uses the `orchestra` package and open DevTools. The inspector extension should appear in the DevTools extensions list.

## Development notes

- The extension sources live in this project and are packaged into the DevTools extension build by `devtools_extensions`.
- To iterate quickly, rebuild and copy the extension after making UI changes.
- See [REFACTOR_PLAN.md](REFACTOR_PLAN.md) for the target architecture and phased refactor plan.
