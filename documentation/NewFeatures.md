# New Features

Features to add to the Inform app, asked for by the maintainer or noticed during the modernisation (`modernisation_plan.md`, Phase 6). When one is done, take it out of here and record it in the plan's Phase 6, with the work it was done in. Open bugs are in `ToFix.md`.

## Preferences

- **A text size for the story and one for the documentation, and the source font called "Source Font".** Asked for by the maintainer in the app run-through (13 November 2026). The Font section of the Editing preferences has two settings. The first, labelled "Font family:", sets the source text's font and size. The second, "Documentation font size:", is the app's text size, which scales the documentation and the story's text, and, from the code, the Index and Extensions pages and the skein too (`IFPreferences.appFontSizeMultiplier`). The first should be called "Source Font", and the second should become two sizes, one for the story and one for the documentation; where the other pages and the skein take their size from is still to decide. The nib already labels the first " Source Font:", but the English strings file replaces it with "Font family:" (in `ToFix.md`).

## Documentation

- **Highlighting the phrase found when a Find in Files result in the documentation is opened** (to consider; noted by the maintainer in the app run-through, 13 November 2026). The result opens its page at the anchor of the definition, code or example it's in, and the phrase has never been highlighted: there's no code for it, in the Objective-C of 2014 as now. The documentation's web view can already find a phrase for the Find panel (`IFFindWebView`, with `WKWebView`'s find, which selects the match), but a page can have the phrase in more than one place, and the one selected should be the result's.

## Quick Look

- **Quick Look preview and thumbnail extensions to replace InformQL.**

## Interpreters

- **Replacing Distributed Objects with `NSXPCConnection`**, coordinated with MaddTheSane upstream.
