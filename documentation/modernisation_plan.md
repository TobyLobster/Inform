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
- [x] Ask MaddTheSane to set `SKIP_INSTALL = YES` on those three targets upstream. Merged 3 November 2026 (MaddTheSane/zoom#2, MaddTheSane/CocoaGlk#5). `configure.py` keeps its edit until Phase 2 moves the submodules past those commits.
- [x] Notarise a release built this way. Archived, notarised and stapled on 3 November 2026; the DMG works.
- [ ] Check a Mac App Store build. ZoomServer now gets the inherited sandbox entitlements like the other helpers (before, it had none).
- [ ] Hosted tests launch the full app with the real `com.inform7.inform-compiler` preferences. Consider skipping start-up work (welcome window, news fetch) when running under XCTest.

### Phase 1a – Clean build, app side (goal 1)

- Review Xcode's recommended project settings one by one; keep manual signing.
- [x] Replace `-Weverything` with a chosen set of warnings (`inform/Config/Warnings.xcconfig`): the project's Xcode warning settings plus a few extras. Warnings went from 766 to 233, of which 86 are the app's own; the rest are in the submodules (Phase 1b).
- [x] Fix the warnings in the app's own code (233 to 147; the rest are in the submodules). Only the Quick Look generator calls are left, for Phase 6.
    - One-bit bitfields in `IFInform6Highlighter.h` made unsigned (every read tested for zero, so no behaviour change).
    - Deliberate fall-throughs annotated; one missing `break` added.
    - Formal protocols declared (`NSMenuItemValidation`, `NSToolbarItemValidation`, `NSControlTextEditingDelegate`).
    - `UTType` for MIME types and panel file types (new `+[IFUtility contentTypesForFilenameExtensions:]`, tested), `NSWorkspace openURL:`, new colours, toolbar width constraints, `-bind_at_load` dropped.
    - Later: `-Warc-repeated-use-of-weak` is off (around 60 places), as it was before.
- [x] Minimum macOS is 13 (decided 3 November 2026; upstream Zoom and CocoaGlk need 12). The Inform and InformQL targets now build for 13.0. This exposed 42 new deprecation warnings (Uniform Type Identifiers, `NSWorkspace openFile:`, `allowedFileTypes`, `validateMenuItem:` without `NSMenuItemValidation`, old Quick Look generator calls, `-bind_at_load`), now in the baseline and to be fixed below.
- Signed manual smoke test on current macOS: compile a project, play Z-code and Glulx games, Skein, Index, documentation, extensions, testing, dark mode.
    - Also check these changes from fixing deprecations: the page bar borders (now `separatorColor`), the toolbar search fields, test case pop-up and status area at different window widths, every open/save panel (new project, export extension, save iFiction, save game, import skein, save transcript) offers and adds the right extension, the IFDB link icon on the welcome window, Show Extensions Folder and Materials Folder, and the Advanced preferences' Inform Core directory label.

### Phase 2 – Merge Zoom and CocoaGlk (goal 2)

- Move Zoom to `origin/madds` (`0c09da21` on 3 November 2026), which records CocoaGlk `d0b0e46`. Both include our `SKIP_INSTALL` changes and require macOS 12.
- Remove the `SKIP_INSTALL` edit from `configure.py`, so it no longer touches the submodules at all.
- Drop the local submodule changes (mostly `configure.py` output and xib churn; the `glk_unicode.m` fix is upstream).
- Fix where the app's use of ZoomView/GlkView no longer matches.
- A fresh clone of upstream Zoom doesn't build ZoomServer: the `Interpreter` step can't find `Builder`, so `build/interp_*.h` are never generated (`'interp_z3.h' file not found`). Our checkout only works because old copies of those headers sit in the ignored `zoom/build/`. Fix upstream, or generate them in our build.

### Phase 1b – Clean build, whole workspace (goal 1)

- Bring the submodule warnings to zero or an agreed level, upstreaming fixes where possible. Test again.

### Phase 3 – Existing bugs (goal 3)

- Triage the GitHub issues, crashes first.
- Found while testing (November 2026):
    - Documentation tab: links on buttons don't work, nor does the examples' Paste button. These go through `-[IFWebViewHelper userContentController:didReceiveScriptMessage:]`. Check whether the 1.84 release (built before Phase 1a) has the same problem.
    - Exception when choosing the Story tab after the game process has stopped: `-[GlkView queueEvent:]` sends `eventReady:` to the listener proxy of a client that has gone. Fix prepared for CocoaGlk upstream (local branch `clear-listener-when-client-exits` in `~/Code/upstream/CocoaGlk`), not yet tested in the app.

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

- What to do about the `extensions` and `master` branches (`extensions` is 63 commits ahead; `master` hasn't moved since April 2023).
