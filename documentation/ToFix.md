# To Fix

Open bugs in the Inform app and in Zoom and CocoaGlk, found during the modernisation (`modernisation_plan.md`). When one is fixed, take it out of here and record the fix in the plan, with the work it was fixed in. Problems that belong in Inform Core itself are in `for_g.txt`, a local, git-ignored list.

Each says how it was found, and none has been seen in the app unless it says so.

## Extension projects

- **The Public Library page and the app disagree about their messages.** `messages_to_objc.js` posts `askInterfaceForLocalVersion`, `askInterfaceForLocalVersionText` and `downloadMultipleExtensions`, which `IFWebViewHelper` doesn't act on, and its `openURL` posts `openFile`, so the helper takes the URL for a file's path. Inform Core's `pl404.html` also uses the first two's return values at once, which WKWebView messages can't give, so this needs an asynchronous design on both sides (see `for_g.txt`). The helper had handlers for the first two under other names, which nothing reached and whose answers were thrown away; they were taken out (a84b8641), and the lookup of an installed extension's version will have to be written for that design. Older than this work; found reading the scripts (November 2026).

## Documentation

- **Searching the documentation is slow.** Find in Files reads and parses every documentation page for each search, and the pages the app has shown since May 2024 are about 100 MB, five times the old ones. A search of the documentation takes about 15 seconds in the tests, in a Debug build, against 4 with the old pages, and the whole test run went from about 205 seconds to 374. The parsed text could be kept between searches, or made when the app is built. Found while making Find in Files search the new documentation (11 November 2026); not timed in the app.
- **The app has the old documentation, which nothing in it opens.** `inform/StagingArea`'s `en.lproj` still has the 558 `doc…` and `Rdoc…` pages (about 20 MB) and `allegs.html`, `Rallegs.html` and `examples_alphabetical.html`, all last changed in August 2023 and linking only to the old pages, and 28 `WI_…` pages from an older version (`WI_25_8` to `WI_25_15`, `WI_26_8` to `WI_26_10`, `WI_27_15` to `WI_27_24` and `WI_30_9` to `WI_30_15`), which have no search markers and which the contents page doesn't link to. They come from Inform Core's `resources/App HTML` folder, which git ignores, and which in the local checkout still has them beside the new pages (its `doc1.html` is from January 2024, its `WI_1_1.html` from 3 November 2026); `compiler_injection.sh` copies the whole folder. Found while making Find in Files search the new documentation (11 November 2026).

## Skein

- **Knots once couldn't be clicked or dragged** (seen in the app on 5 November 2026, in a build of `phase5/swift-utility-rest`), then could again in the same run. Not reproduced. The branch `debug/skein-clicks` logs the skein's mouse events, tagged "SKEIN", to read with `log show`. An idea, not checked: the knots' tracking areas use `NSTrackingActiveInKeyWindow`, so if the window wasn't key, a knot under the pointer might never be marked as inside, and a click only acts on a knot that is.

## Building

- **Fresh clones of Zoom don't build ZoomServer.** The external-build-tool `Interpreter` target runs before `Builder` is linked, so `build/interp_*.h` are never generated (`'interp_z3.h' file not found`). It works here because old headers sit in the ignored `zoom/build/` (the same code as freshly generated ones, apart from `#line` paths and order), and until it's fixed a fresh clone of Inform hits it too. The fix generates the headers in a ZoomServer Run Script phase that declares Builder as an input: sent as MaddTheSane/zoom#3 (branch `generate-interpreter-headers` in `~/Code/upstream/zoom`), and applied uncommitted to our `zoom/` until it's merged. Found on 3 November 2026.

## Zoom and CocoaGlk

- **Possibly real, from the static analyser** (4 November 2026), to look at upstream: a possible null `win->stream` in `glk_window_set_echo_stream` (`glk_windows.m`), a nil font in an attributes dictionary (`ZoomTextView.m`), a variable-length array that could have a negative size (`GlkTypesetter.m`), null `buf` arrays with a non-zero length in `glk_stream.m` and `glk_unicode.m`, and leaks in Zoom's `debug.c` and `rc.c`.

## GitHub issues

- Open on 6 November 2026: #29 (dark mode for the story view) and #31 (colour-blind options), both requests for features rather than bugs.
