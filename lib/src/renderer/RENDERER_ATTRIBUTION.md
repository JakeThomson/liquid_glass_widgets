# Vendored: liquid_glass_renderer

This directory contains source code vendored from
[`liquid_glass_renderer`](https://github.com/whynotmake-it/flutter_liquid_glass/tree/main/packages/liquid_glass_renderer)
by **whynotmake.it**, licensed under the **MIT License**.

Vendored version: **0.2.0-dev.4** (vendored 2026-03-28)

## Why vendored

`liquid_glass_renderer` has not published a new version to pub.dev since
November 2025. Vendoring gives `liquid_glass_widgets` full control over bug
fixes and improvements without waiting on upstream releases.

## Syncing upstream changes

Use the sync script for new upstream releases:

```bash
./tools/sync_renderer.sh <version>
# e.g. ./tools/sync_renderer.sh 0.2.0-dev.5
```

The script automatically:
- Copies and import-fixes the 11 "clean" Dart files
- Syncs the 6 shaders we use
- Stages the 5 structurally-modified files for manual diff
- Updates this file's version/date
- Runs `flutter analyze`

After the script: manually reconcile the 5 staged structural files
(`liquid_glass.dart`, `liquid_glass_render_scope.dart`,
`liquid_glass_blend_group.dart`, `rendering/liquid_glass_layer.dart`,
`shaders.dart`), then delete `.upstream_<version>/` and run `flutter test`.

Mark any local deviations with `// [LOCAL PATCH]: <reason>` so they are
obvious during the next sync.

## Local patches

None yet.
