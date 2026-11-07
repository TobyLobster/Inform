# To Fix

Open bugs in the Inform app and in Zoom and CocoaGlk, found during the modernisation (`modernisation_plan.md`). When one is fixed, take it out of here and record the fix in the plan, with the work it was fixed in. Problems that belong in Inform Core itself are in `for_g.txt`, a local, git-ignored list.

Each says how it was found, and none has been seen in the app unless it says so.

## Running Inform's tools

- **Some run-time problems are never shown.** When turning a run-time problem's Markdown into a page fails, `IFProjectController`'s `runtimeError:inDirectory:` returns without showing anything, so neither the problem nor the error page that `IFInBuild` writes is seen. Found by reading (6 November 2026).
- **Every project's Errors page shows every project's intest runs.** `IFCompilerController` observes InTest's notifications from any object, so with two projects open, each console shows the other's runs too, such as the catalogue made whenever an extension project is opened or saved. Found by reading (6 November 2026).
- **A tool that wrote a lot of errors would hang the app.** `IFInBuild` and `IFInTest` only read a tool's stderr once its stdout has ended, so if it wrote more to stderr than a pipe holds (64 KB), each would wait for the other. inbuild and intest write a line or two there. Found by reading (6 November 2026).
- **A missing tool raises an exception.** If `inbuild` or `intest` can't be found, which can only happen with an external Inform Core folder (Advanced preferences), launching it raises. `IFMaintenanceTask` raises the same way for a command it can't run, and its queue is then stuck, though the only command it's given is the app's own 6M62 `ni`. Found by reading (6 November 2026).
- **The `build.sh` stage can be left queued.** With "Rebuild I7 compiler as needed" chosen in the Advanced preferences (for maintainers of Inform), `IFCompiler`'s `prepareForLaunchWithBlorbStage:testCase:` queues `~/build.sh` before checking that there's an Inform 7, and when there isn't (only possible with an external Inform Core folder), it returns NO with that stage still queued, so the next build runs only `build.sh`. Found by reading (6 November 2026).
- Harmless as the app uses it: `IFMaintenanceTask` only posts the last task's notification, when the queue empties, so a task queued behind another never posts its own. Every run of censuses ends with `IFCensusFinished`, which everything that observes the other census notification observes too. A test pins it.

## Extension projects

- **Examples with the same title choose the wrong test case.** `IFToolbarManager`'s `setTestCases:` adds each example's title to the test case pop-up, and a pop-up button given a title it already has removes the earlier item (checked with a probe, 6 November 2026). So for examples titled "Lighthouse", "Café" and "Lighthouse", the menu offers only Café and Lighthouse, and as its items are matched to the test cases by position, choosing Café runs A and choosing Lighthouse runs B.
- **The Public Library page and the app disagree about their messages.** `messages_to_objc.js` posts `askInterfaceForLocalVersion`, `askInterfaceForLocalVersionText` and `downloadMultipleExtensions`, and `openURL` posts `openFile`, but the handler expects `askInterfaceForLocalVersionAuthor` and `askInterfaceForLocalVersionTextAuthor`, has no `downloadMultipleExtensions`, and ignores `openURL`. Inform Core's `pl404.html` also uses the first two's return values at once, which WKWebView messages can't give, so this needs an asynchronous design on both sides (see `for_g.txt`). Older than this work; found reading the scripts (November 2026).
- **An extension project's skeins can be passed over, or left over.** `IFProjectFile` finds each of `SkeinA.skein`, `SkeinB.skein` and so on by comparing file names without regard to case, but then reads it by its exact name, so one named in other case, such as `skeina.skein`, is passed over, with every letter after it. And writing fewer skeins than there are files leaves the later files in the project, to be read again when it's next opened; what `IFProject` then does with the extra skein isn't checked. Neither is likely. Found with the `IFProjectFile` tests (6 November 2026).

## Projects

- **Revert To Saved doesn't revert a project.** The File menu's Revert To Saved reads the project again, which gives `IFProject` new texts for its source files, but the source page keeps showing, and editing, the old ones, so edits made after reverting aren't saved. And reading the skeins again adds them to the ones the project has (`IFProjectFile`'s `loadIntoSkeins:` doesn't empty the list first), so the project goes on showing its old skein. Found by reading (6 November 2026).
- **Retrying a failed Save Compiler Output loses its window.** `IFProject`'s `saveCompilerOutputWithWindow:` forgets its window as soon as the save panel is shown, so when the copy fails and Retry is chosen, it's tried again with no window: the save panel is begun as a sheet on no window (which, for `IFUtility`'s alerts, showed nothing at all), and the Swift method, which declares its window non-null, is given nil. Found by reading (6 November 2026).
- **Saving the iFiction record, or exporting an extension, over an existing file does nothing.** The save panel asks whether to replace the file, but the copy fails when the file is there, and the failure isn't reported, so the old file stays. Save Compiler Output removes the old file first. Found by reading (6 November 2026).
- **New Extension could raise if its project went away.** The New Extension window holds its project weakly, so if the project were freed while the window was open, Create would raise, having no filename for the extension. Found by reading (5 November 2026).
- **`allWindows` skips the first window.** `IFAppDelegate`'s `allWindows` skips the first window in the list, which is the frontmost unless something not the app's own is listed first. When the app is active something is, so it does no harm then; it's not checked when the app isn't active. New Extension and the Extensions menu use it. Found on the way (6 November 2026).

## Editing

- **Replace doesn't expand a regular expression's replacement.** Replace, unlike Replace and Find and Replace All, inserts the replacement as typed, so with a regular expression it inserts `\1`. Found with the `IFScanner` tests (4 November 2026).
- **Find All in Files waits for a search already running.** A Find in Files search runs on another thread, holding `IFFindInFiles`' lock on its list of things to search, and starting one takes that lock on the main thread. So clicking Find All while a search runs stops the app until that search ends (a search of the documentation took about 3 seconds in the tests, in a Debug build). Then the first search's last progress report, queued meanwhile, stops and hides the progress indicator while the new search runs. Found by reading (6 November 2026).
- **Uncommenting two comments leaves brackets.** Uncommenting a selection of two comments with source between them, such as `[a] b [c]`, takes away only the first and last brackets, leaving `a] b [c`. Found with the comment helpers' tests (5 November 2026).
- **A heading numbered in words stops the numbering.** A heading whose number is a word, such as "Chapter Two", has no number as far as numbering is concerned, so a heading typed after it isn't numbered. Found with the `IFNaturalIntel` tests (5 November 2026).
- **Pasted source can lose the start of a comment.** `IFUtility`'s `unescapeString:`, which decodes code pasted from the documentation, runs an escape to the next `=]`, so pasted source with a comment starting `[=`, as in `[=== Notes ===]`, gets a `?` in its place. Inform's documentation only uses `[=0x....=]` escapes. Found with the `IFUtility` tests (5 November 2026).
- **An Inform 6 header opened on its own isn't highlighted.** A `.h` file opened on its own has the document type `public.c-header`, which `IFProjectTypes`' `fileTypeFromString:` takes for an Inform 6 ICL file, so `IFSingleFile` shows it as Latin-1 with no highlighting. Yet `highlighterTypeForFilename:` gives `.h` files Inform 6 highlighting, as in a project. The code pairs the two on purpose, so it may be meant. Found by reading (6 November 2026).

## Documentation

- **Find in Files searches the old documentation.** `IFFindInFiles`' `addDocumentation` searches the pages named `doc…` and `Rdoc…` (558 of them, last changed in August 2023), but since May 2024 (12375aed) the documentation the app shows is the `WI_…` and `RB_…` pages, which the contents page links to and which are numbered differently: 11.3 is now "Dialogue beats and their cues", not "Pattern matching". So documentation results give the old section numbers and open the old pages, and nothing written since is found. To search the new pages, `IFDocParser` would need to recognise their markers, which have spaces inside the comment (`<!-- SEARCH TITLE "…" -->`), and the Recipe Book test would have to change: the new sort keys start `001` for Writing with Inform and `002` for the Recipe Book, where the old ones started `000` and `001`, and `IFFindResult`'s `recipeBookResult` checks for `001`. The new pages have no example markers, and one search title, `"Making the verb "to weigh""`, has quotes inside it. Found while testing `IFDocParser` (6 November 2026).
- **Help > Recipe Book opens the old Recipe Book.** `IFProjectController`'s `docRecipes:` opens `Rdoc1.html`, the old Recipe Book's first page, not the new one's contents page, `RB_index.html`. Found by reading (6 November 2026).

## Preferences

- **A colour theme with an option it can't read loses all your themes.** The themes are kept in the preferences as an archive. `IFColourTheme`'s `initWithCoder:` adds each option it reads to its options, so one that reads as nothing (an option with a colour missing, since 24930703) raises an exception. `IFPreferences`' `getPreferenceThemes` catches it and gives no themes, so the app starts again with the standard themes and writes them over yours. A theme with no paper colour is left out instead. Only a damaged preferences file would have such an option. Found by reading (7 November 2026).

## Skein

- **A "test me" knot's made-up transcript is lost.** A "test me" knot with no blessed transcript is written with one made of its commands' headings, such as `[1] jump`, which the app reads back as none. Found with the `IFSkein` tests (5 November 2026).
- **Knots once couldn't be clicked or dragged** (seen in the app on 5 November 2026, in a build of `phase5/swift-utility-rest`), then could again in the same run. Not reproduced. The branch `debug/skein-clicks` logs the skein's mouse events, tagged "SKEIN", to read with `log show`. An idea, not checked: the knots' tracking areas use `NSTrackingActiveInKeyWindow`, so if the window wasn't key, a knot under the pointer might never be marked as inside, and a click only acts on a knot that is.

## Quick Look

- **The plugin would raise if it reached the string category.** The Quick Look plugin compiles `IFUtility.m` and `IFNaturalIntel.m`, which call the `NSString` category, but not the category itself, so those calls would raise there if they were reached. Found by reading (5 November 2026). InformQL itself may no longer load on macOS 15; replacing it is Phase 6.

## Building

- **Fresh clones of Zoom don't build ZoomServer.** The external-build-tool `Interpreter` target runs before `Builder` is linked, so `build/interp_*.h` are never generated (`'interp_z3.h' file not found`). It works here because old headers sit in the ignored `zoom/build/` (the same code as freshly generated ones, apart from `#line` paths and order), and until it's fixed a fresh clone of Inform hits it too. The fix generates the headers in a ZoomServer Run Script phase that declares Builder as an input: sent as MaddTheSane/zoom#3 (branch `generate-interpreter-headers` in `~/Code/upstream/zoom`), and applied uncommitted to our `zoom/` until it's merged. Found on 3 November 2026.

## Zoom and CocoaGlk

- **Possibly real, from the static analyser** (4 November 2026), to look at upstream: a possible null `win->stream` in `glk_window_set_echo_stream` (`glk_windows.m`), a nil font in an attributes dictionary (`ZoomTextView.m`), a variable-length array that could have a negative size (`GlkTypesetter.m`), null `buf` arrays with a non-zero length in `glk_stream.m` and `glk_unicode.m`, and leaks in Zoom's `debug.c` and `rc.c`.

## GitHub issues

- Open on 6 November 2026: #29 (dark mode for the story view) and #31 (colour-blind options), both requests for features rather than bugs.
