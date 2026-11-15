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

## Documentation

- **Searching the documentation is slow.** Find in Files reads and parses every documentation page for each search, and the pages the app has shown since May 2024 are about 100 MB, five times the old ones. A search of the documentation takes about 15 seconds in the tests, in a Debug build, against 4 with the old pages, and the whole test run went from about 205 seconds to 374. The parsed text could be kept between searches, or made when the app is built. Found while making Find in Files search the new documentation (11 November 2026); not timed in the app. Left for now (14 November 2026): Release builds are faster, and the maintainer hopes to move the pages' CSS into a separate file, which should make it faster still.

## Building

- **Fresh clones of Zoom don't build ZoomServer.** The external-build-tool `Interpreter` target runs before `Builder` is linked, so `build/interp_*.h` are never generated (`'interp_z3.h' file not found`). It works here because old headers sit in the ignored `zoom/build/` (the same code as freshly generated ones, apart from `#line` paths and order), and until it's fixed a fresh clone of Inform hits it too. The fix generates the headers in a ZoomServer Run Script phase that declares Builder as an input: sent as MaddTheSane/zoom#3 (branch `generate-interpreter-headers` in `~/Code/upstream/zoom`), and applied uncommitted to our `zoom/` until it's merged. Found on 3 November 2026.

## Zoom and CocoaGlk

Found looking for bugs in Zoom and CocoaGlk at `origin/madds` (15 November 2026; see the plan's Phase 4), and to be fixed upstream. Those that say so were reproduced with small programs that call the built frameworks, with no game running; the others were traced through the code. None has been seen in the app.

- **`@erase_line` in Zoom's lower window raises.** `ZDisplay.m` sends `eraseLineWithStyle:` to the current window whichever it is, but `ZoomLowerWindow` doesn't implement it, so `@erase_line 1` in the lower window raises inside `flushBuffer:`. The rest of that buffer is lost, and `editingTextView` stays set. It should only go to the upper window.
- **Delete in Zoom's `read_char` arrives as '?'.** The Mac's Delete key gives U+007F, which `ZDisplay.m` passes to `zscii_get_char`, giving '?'; the Standard wants 8.
- **Case changes and normalisation in CocoaGlk.** `glk_buffer_to_title_case_uni` capitalises every word, where the spec changes only the first character (reproduced: "Hello World"). `glk_char_to_upper(0xDF)` gives 'S', where the spec leaves a character unchanged if it doesn't become one character (reproduced). `glk_buffer_canon_normalize_uni` and `glk_buffer_canon_decompose_uni` crash for an invalid code point, such as a lone surrogate, as its string is nil (reproduced).
- **`glk_window_set_arrangement` with no key window clears the key.** The spec says a NULL key window leaves the key as it was; Inform 7 passes 0. Then the view has no key, which matters only for nested fixed splits, as `GlkPairWindow` sizes them by its right-hand child. Related: `glk_window_close` clears `parent->parent` before discarding the parent, so a grandparent whose key was the closed window keeps a freed pointer (`glk_windows.m`).
- **Images in text buffer windows.** `glk_image_draw` returns 0 although it draws, and `glk_image_draw_scaled` draws nothing (`glk_image.m`).
- **Unicode line input can report one character more than it wrote.** `glk_events.m` copies `bufLen-1` characters but limits `val1` to `bufLen`.
- **Accessibility queries raise when there's no root window.** `GlkView.m` answers the accessibility children with `@[rootWindow]`, which raises before the first window opens or after the root window closes.
- **Smaller ones in CocoaGlk.** `GlkStyle` never sets `lastScaleFactor`, so its cache of attributes is never used; merging arrange events compares the views' `identifier`s, which are always nil; `GlkPreferences`' `changeNotified` is never reset; `GlkEvent` isn't sent `bycopy`, so each event takes about five round trips to the interpreter; and glulxe passes NULL for an array of length 0, which `glk_get_buffer_stream` and the other reading functions treat as an error that ends the game.
- **Not confirmed, but plausible:**
    - `glk_cancel_line_event` always reports `evtype_LineInput`, where the spec wants `evtype_None` if no line input was requested. The view would have to say whether it was.
    - Restoring a Quetzal save trusts its lengths (`state.c`): a chunk length of 0xFFFFFFF8 loops for ever, and `CMem` is written before the end of memory is checked. Needs a damaged save.
    - Two Zoom views starting at once may each be paired with the other's server (`ZoomConnector.m`).
    - A second running copy of Inform can't register the Glk hub's fixed name, "GlkInform", so its stories' interpreters reach the first copy. The session cookies come from `random()`, never seeded.
    - Duplicate input receivers could change `GlkView`'s `inputReceivers` while it's being enumerated.
    - Line input in a text grid with the cursor off the grid may raise (`GlkTextGridWindow.m`).
    - In ZoomView: a dead key while terminating characters are set raises (AppKit logs it); the window key notifications are registered with the old window when the view moves to another; an unbalanced `@output_stream -3` writes two zeros into dynamic memory (`interp.c`); and the screen height is taken from the document view's bounds.
    - `glk_schannel_play_multi` counts by the wrong array when the two counts differ, which is an illegal call anyway.
    - Slow, not wrong: read-only binary files, and Unicode file streams, take a round trip to Inform for each character.
- The static analyser's findings in their own code, which were listed here, were checked by hand. Apart from `glk_style_measure`'s (in the plan), they are false positives, or small leaks in Zoom's `debug.c` and `rc.c`, of debugging information and at start-up.

## GitHub issues

- Open on 6 November 2026: #29 (dark mode for the story view) and #31 (colour-blind options), both requests for features rather than bugs.
