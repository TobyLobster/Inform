# To Fix

Open bugs in the Inform app and in Zoom and CocoaGlk, found during the modernisation (`modernisation_plan.md`). When one is fixed, take it out of here and record the fix in the plan, with the work it was fixed in. Problems that belong in Inform Core itself are in `for_g.txt`, a local, git-ignored list.

Each says how it was found, and none has been seen in the app unless it says so.

## Extension projects

- **The Public Library page and the app disagree about their messages.** `messages_to_objc.js` posts `askInterfaceForLocalVersion`, `askInterfaceForLocalVersionText` and `downloadMultipleExtensions`, which `IFWebViewHelper` doesn't act on, and its `openURL` posts `openFile`, so the helper takes the URL for a file's path. Inform Core's `pl404.html` also uses the first two's return values at once, which WKWebView messages can't give, so this needs an asynchronous design on both sides (see `for_g.txt`). The helper had handlers for the first two under other names, which nothing reached and whose answers were thrown away; they were taken out (a84b8641), and the lookup of an installed extension's version will have to be written for that design. Older than this work; found reading the scripts (November 2026).
- **A download from the Public Library can't be installed once the next one has arrived.** Downloads go one at a time, and each is handed to the project controller as it arrives, which runs inbuild to report on it and keeps it as the one extension whose install the report's button confirms (`IFProjectController.installExtensionURL`, `confirmInbuildAction`). So if a second download arrives before the first's install is confirmed, its report takes the first's place, and the first has to be downloaded again. Older than this work (1ff5bca8, August 2023); found reading the code while removing the temporary copies of installed extensions (14 November 2026). Not seen in the app. Left for now (14 November 2026): downloads are meant to go one at a time, and the maintainer is content with that for now.
- **An example with a heading can't be tested in an extension project.** Inform 10.2 warns about files in a project's bundle that an ordinary project doesn't have, and an extension project always has some: `Source/extension.i7x` beside `story.ni`, and a skein for each example, `SkeinA.skein` and so on, in place of `Skein.skein` (`IFProjectFile`). That would only be a warning, but in Inform 10.2 a warning about a project's files stops ni with "internal error (Parse tree broken)" when the source has a heading, so testing an example whose source has one fails, as example E of Approaches by Emily Short, "Riverside Path", did for the maintainer (14 November 2026). Reproduced with the bundled ni on copies: with the skeins and `extension.i7x` moved out, the example compiles, and an ordinary project with a heading and one extra file fails the same way. Both halves are Inform Core's, and are in `for_g.txt` (items 13 and 14), with the question of what an extension project should look like for 10.2; the app's side is the layout, if Inform Core doesn't come to accept it.

## Source editing

Found checking the fixes in the app, in a Debug build (12 November 2026), and not yet compared with the released app.

- **Recolouring a large source is slow.** Typing a `[` at the start of Monkey.inform, whose source is 1.7 MB, makes the rest of it a comment, and `IFSyntaxData` highlights all 25,837 lines again before the keystroke finishes: 2.3 seconds in Debug and 0.67 in Release, timed in the test host. The time is spread over hinting each line, clearing the intelligence's symbols a line at a time, setting paragraph styles and fixing fonts line by line, and `@objc` calls for each character. Speeding those up might halve it. Highlighting what's shown first and the rest later would make it immediate, but the headings, sections, elastic tabs and find rely on the highlighting being complete. Left for now (14 November 2026): the maintainer finds it fast enough, especially in Release.

## Preferences

- **The English strings files and the nibs disagree on four labels.** English is shown from `en.lproj`'s strings, not the Base nib. The Editing preferences' source font is labelled "Font family:" there (as the maintainer saw in the app) and its styles box "Styles", where the nib has " Source Font:" and "Style", both since May 2022 (72c2eb80, which also last changed the strings). The Colour preferences' themes are "Dark Mode" and "Light Mode" in the strings, and "Dark" and "Light" in the nib. Which wording is wanted is the maintainer's call; the labels in `NewFeatures.md` would need the strings changed too. `EditingPreferences.strings` also has 76 entries for objects no longer in the nib, which do nothing. Found comparing the strings with the nibs (13 November 2026).

## Menus and the launcher

- **The main menu's English strings and its nib disagree on six items.** As with the preferences, English is shown from `en.lproj`'s strings, not the Base nib, so users see "Show Tab" where the nib has "Show Views", "New Extension Project..." for "New Extension Project", "Add Extension to Project..." for "Add Extension to Project", "Creating a New Extension..." for "Create a New Extension...", "From the Public Library" for "From the Public Library...", and "Export Extension..." for "Export from Extension Project...". The three submenus' own titles differ in the same way. No code sets these titles. `MainMenu.strings` also has 18 entries for objects no longer in the nib, which do nothing, as do one in `Find.strings` and three in `FindInFiles.strings`. The launcher's `Launcher.strings` has "GitHub" where its nib has "Github". Which wording to keep is the maintainer's choice. Found comparing every strings file with its nib (14 November 2026).

## Documentation

- **Searching the documentation is slow.** Find in Files reads and parses every documentation page for each search, and the pages the app has shown since May 2024 are about 100 MB, five times the old ones. A search of the documentation takes about 15 seconds in the tests, in a Debug build, against 4 with the old pages, and the whole test run went from about 205 seconds to 374. The parsed text could be kept between searches, or made when the app is built. Found while making Find in Files search the new documentation (11 November 2026); not timed in the app. Left for now (14 November 2026): Release builds are faster, and the maintainer hopes to move the pages' CSS into a separate file, which should make it faster still.

## Building

- **Fresh clones of Zoom don't build ZoomServer.** The external-build-tool `Interpreter` target runs before `Builder` is linked, so `build/interp_*.h` are never generated (`'interp_z3.h' file not found`). It works here because old headers sit in the ignored `zoom/build/` (the same code as freshly generated ones, apart from `#line` paths and order), and until it's fixed a fresh clone of Inform hits it too. The fix generates the headers in a ZoomServer Run Script phase that declares Builder as an input: sent as MaddTheSane/zoom#3 (branch `generate-interpreter-headers` in `~/Code/upstream/zoom`), and applied uncommitted to our `zoom/` until it's merged. Found on 3 November 2026.

## Zoom and CocoaGlk

- **Possibly real, from the static analyser** (4 November 2026), to look at upstream: a possible null `win->stream` in `glk_window_set_echo_stream` (`glk_windows.m`), a nil font in an attributes dictionary (`ZoomTextView.m`), a variable-length array that could have a negative size (`GlkTypesetter.m`), null `buf` arrays with a non-zero length in `glk_stream.m` and `glk_unicode.m`, and leaks in Zoom's `debug.c` and `rc.c`.

## GitHub issues

- Open on 6 November 2026: #29 (dark mode for the story view) and #31 (colour-blind options), both requests for features rather than bugs.
