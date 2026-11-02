# Modernisation Plan for the macOS Inform App

Started November 2026, on the `extensions` branch. This is a living document: update it as phases complete or decisions change.

## Goals, in order

1. Compile cleanly and work with the latest Xcode.
2. Merge in the latest versions of the Zoom and CocoaGlk submodules.
3. Fix existing bugs.
4. Find and fix new bugs.
5. Convert the source to Swift, in managed stages.
6. Add new features.

## Starting point (November 2026)

- Xcode 26.3 (macOS SDK 26.2) on macOS 15.7. A clean, unsigned Debug build succeeds with 0 errors and 711 unique warnings (`documentation/warnings_baseline.txt`).
    - 519 of those are `-Wdeclaration-after-statement`, which appears because the Inform target uses `-Weverything` and every new Clang adds warnings.
    - Others worth fixing: 80 single-bit bitfield conversions in `IFInform6Highlighter.m` (assigning YES to a 1-bit field gives -1, possibly a real bug), format-string mismatches, missing `default:` labels, and a deprecated `endSheet` call in `IFNewThemeWindow.swift`.
    - In the submodules: deprecated `NSConnection`/`NSDistantObject` (Distributed Objects), WebKit 1 `WebDataSource`, `NSReadPixel`, `NSUnarchiver`, `mktemp`.
- The app is about 42k lines of Objective-C (117 `.m` files) and 1k lines of Swift (21 files).
- The project file is at Xcode 13.1 level (`LastUpgradeCheck = 1310`), deployment target macOS 10.14, Swift 5.0.
- Zoom is 190 commits behind `MaddTheSane/zoom` `madds`; CocoaGlk is 16 behind `MaddTheSane/CocoaGlk` `madds`. Zoom records CocoaGlk at `eb26b55`, but `4b31951` is checked out.
- The local change to CocoaGlk's `GlkClient/glk_unicode.m` is superseded by upstream commit `622461f` (fixes issue #41).
- InformQL is a `.qlgenerator` plugin. macOS 15 is believed to no longer load these (not yet verified). Upstream Zoom now has Swift Quick Look extensions (`ZoomNewSaveQL`, `ZoomThumbnailer`) that show a replacement pattern.
- RegexKitLite (uses the deprecated `OSSpinLock`) is used in three files.
- There were no tests.

## Ground rules

- **Signing stays manual.** The app runs separately signed command-line tools and interpreter processes, so Xcode's "Update to recommended settings" is reviewed change by change, never accepted wholesale.
- **Review is local.** Work happens on local branches as small commits for review; nothing is pushed without asking.
- **Submodules track MaddTheSane's `madds` branches.** Fixes we need go upstream as pull requests; fork only if a patch is Inform-specific and won't be accepted.
- **Swift conversion is one-to-one.** Keep AppKit and the xibs. A commit either moves logic or translates it, never both. SwiftUI is undecided.
- **The StagingArea binaries stay in git** as they are.

## Phases

### Phase 0 – Groundwork

- [x] Make the Inform Core rebuild opt-in (`inform/Config/Inform.xcconfig`, `Local.xcconfig`).
- [x] Command-line build script with a warnings baseline (`inform/Scripts/cli_build.sh`).
- [x] Unit-test target (`InformTests`, hosted in Inform.app) with a first test (`IFSemVer`).
- [x] `CLAUDE.md`, this plan, and updated build documentation.
- [x] Keep the submodule trees clean. `configure.py` no longer edits the submodule projects, except `SKIP_INSTALL` on `Builder`, `ZoomServer` (Zoom) and `GlkView` (CocoaGlk) for release builds. The final build phase now signs ZoomServer and re-seals ZoomView.framework. Debug builds are active-architecture only. Verified with untouched submodule projects: signed Debug build, and a Developer ID archive exported by Xcode with every executable Developer ID signed, hardened runtime, timestamped and universal.
- [ ] Ask MaddTheSane to set `SKIP_INSTALL = YES` on those three targets upstream (PR text drafted), then drop the last submodule edit from `configure.py`.
- [ ] Notarise a release built this way, and check a Mac App Store build. ZoomServer now gets the inherited sandbox entitlements like the other helpers (before, it had none).
- [ ] Hosted tests launch the full app with the real `com.inform7.inform-compiler` preferences. Consider skipping start-up work (welcome window, news fetch) when running under XCTest.

### Phase 1a – Clean build, app side (goal 1)

- Review Xcode's recommended project settings one by one; keep manual signing.
- Replace `-Weverything` with a chosen set of warnings.
- Fix the real warnings in the app's own code.
- Decide the minimum macOS version (currently 10.14; to be raised).
- Signed manual smoke test on current macOS: compile a project, play Z-code and Glulx games, Skein, Index, documentation, extensions, testing, dark mode.

### Phase 2 – Merge Zoom and CocoaGlk (goal 2)

- Move Zoom to `origin/madds`, which records CocoaGlk `f5a7fe2`.
- Drop the local submodule changes (mostly `configure.py` output and xib churn; the `glk_unicode.m` fix is upstream).
- Fix where the app's use of ZoomView/GlkView no longer matches.
- A fresh clone of upstream Zoom doesn't build ZoomServer: the `Interpreter` step can't find `Builder`, so `build/interp_*.h` are never generated (`'interp_z3.h' file not found`). Our checkout only works because old copies of those headers sit in the ignored `zoom/build/`. Fix upstream, or generate them in our build.

### Phase 1b – Clean build, whole workspace (goal 1)

- Bring the submodule warnings to zero or an agreed level, upstreaming fixes where possible. Test again.

### Phase 3 – Existing bugs (goal 3)

- Triage the GitHub issues, crashes first.

### Phase 4 – New bugs (goal 4)

- Static analyser, Address and Thread Sanitizers, Main Thread Checker.
- Unit tests for the classes that are already free of UI: skein XML, index file, runtime error parser, highlighters, settings.

### Phase 5 – Swift, and separating logic from UI (goal 5)

- First add nullability and generics annotations to the Objective-C headers.
- Classes that are already separate from the UI: add tests, then convert one-to-one, bottom-up (utilities and categories, then model classes).
- Big controllers (`IFProjectController`, `IFCompilerController`, `IFSourcePage`, …): move one coherent piece of logic at a time into a new Swift class with no AppKit, with unit tests (for example a build pipeline that runs compile, inform6, blorb and tests). Once a controller is mostly UI, convert the rest one-to-one.
- Replace RegexKitLite with `NSRegularExpression`.
- Swift 5 language mode first; Swift 6 strict concurrency at the end.

### Phase 6 – New features (goal 6)

- Quick Look preview and thumbnail extensions to replace InformQL.
- Replacing Distributed Objects with `NSXPCConnection`, coordinated with MaddTheSane upstream.

## Open decisions

- Minimum macOS version.
- What to do about the `extensions` and `master` branches (`extensions` is 63 commits ahead; `master` hasn't moved since April 2023).
