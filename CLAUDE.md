# InformApp

The macOS IDE for Inform 7. Mostly Objective-C, with some Swift. The modernisation roadmap and its current state are in `documentation/modernisation_plan.md`; how to build and release is in `documentation/building_inform.md`.

## Layout

- `Inform.xcworkspace` → `inform/Inform.xcodeproj`, with targets `Inform` (the app), `InformQL` (Quick Look plugin) and `InformTests` (unit tests).
- `inform/` is the app source. `IFProject` (NSDocument) and `IFProjectController` (window controller) are the core; `Project/Pages/` holds the Source, Errors, Index, Skein, Game, Documentation, Extensions and Settings pages. `Compiler/`, `InBuild/` and `InTest/` run the command-line tools (`ni`, `inform6`, `cBlorb`, `inbuild`, `intest`) with NSTask.
- `zoom/` is a submodule (MaddTheSane/zoom, branch `madds`), with CocoaGlk nested at `zoom/depends/CocoaGlk`. ZoomView and GlkView run games in separate interpreter processes (ZoomServer, glulxe-client, git-client) and talk to them with Distributed Objects.
- `inform/StagingArea/` holds Inform Core binaries and resources (tracked in git), copied into the app by `inform/Scripts/final_build_phase.sh`.

## Building

- Check a build with `inform/Scripts/cli_build.sh` (clean, unsigned Debug into `build/`). Add `--test` to run the unit tests. It prints warnings by flag and compares them with `documentation/warnings_baseline.txt`; don't add new warnings, and update the baseline with `--update-baseline` when warnings are deliberately fixed. The extra warning flags are in `inform/Config/Warnings.xcconfig`; don't bring back `-Weverything`.
- The build only runs `make` in Inform Core and rewrites `inform/StagingArea` when `INFORM_CORE_UPDATE = YES` (set in the gitignored `inform/Config/Local.xcconfig`). The script always passes NO unless given `--update-core`.
- `configure.py` sets signing, sandbox and version settings in the main project. It doesn't edit the submodule projects; signing of everything embedded happens in the Inform target (Copy phases with Code Sign On Copy, plus `final_build_phase.sh`). Don't run it without being asked.
- `xcodebuild archive` runs the scheme's post-archive action (`inform/Scripts/post_archive.sh`), which exports, builds a DMG and writes `~/inform_post_archive_output.txt`. Don't archive without being asked.

## Rules

- Code signing is manual and must stay manual. Never accept Xcode's "Update to recommended settings" wholesale; review each change and call out anything touching signing or entitlements.
- Work on local branches in small commits for the maintainer to review. Don't push.
- Don't commit changes inside `zoom/` or its submodules without being asked. Fixes for Zoom/CocoaGlk should be made so they can go upstream.
- Swift conversion is one-to-one. A commit either moves logic or translates it to Swift, never both.
- Match the surrounding code's style. App classes use the `IF` prefix.
- Unit tests live in `inform/InformTests/` (Swift, hosted in Inform.app). App classes are made visible to them through `InformTests-Bridging-Header.h`; add header search paths to the `InformTests` target as needed.
