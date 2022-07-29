# The Inform Application for macOS

## What's New
A new beta version of the Inform App is now available (as soon as I have uploaded a release!). New features are listed below, and it is now Apple Silicon native while still supporting Intel Macs. A great deal of modernisation has gone on under the hood, but this still remains a work in progress. The minimum requirement is now macOS 10.14 (Mojave). Users on older OS versions can of course continue using previous releases.

- The launcher screen shows the latest News from the IFTF.
- Colour schemes have been introduced (see the preferences pane).
- Support for Dark Mode.
- New icons for Preferences.
- Support for 'Basic Inform'.
- Fixes for skeins misdrawing in some cases.
- Support for the old Inform 6 projects has been removed.

Many thanks to MaddTheSane for a heroic number of modernisations, tweaks and fixes under the hood.

### Work in the pipeline / Known Issues
- Release with winning node marked with '***' in Skein not currently working?
- Updating to latest libraries.
- Dark mode for more views.
- Modernisation to Swift, and away from deprecated APIs.

## About Inform
Inform is a design system for interactive fiction based on natural language, a new medium of writing which came out of the "text adventure" games of the 1980s. It has been used by many leading writers of IF over the last twenty years, for projects ranging from historical reconstructions, through games, to art pieces, which have won numerous awards and competitions.

Inform's educational users span a uniquely wide age range, from primary schools to graduate computer science classes. Although Inform has also been used for commercial commissions, in architecture, in the games industry and in advertising (most recently for a major 2014 product launch), its primary aim is to help and to encourage individual writers to express themselves in a new medium. In a single evening with Inform, it's possible to write a vignette and publish it as an interactive website, playable on any browser.

The Inform project was created by Graham Nelson in 1993 and first came to the Macintosh Programmer's Workshop in 1995, but now makes its debut on the Mac App Store as a state-of-the-art OS X app. It combines the core Inform software with full documentation, including two iBooks and nearly 500 fully working Examples. Connecting to the Inform website, it can automatically download and update extensions from a fully curated Public Library used by the world-wide Inform community. The app offers richly detailed indexing of projects and scales from tiny fictions like "Kate is a woman in the Research Lab" right up to enormous imaginary worlds whose source text runs to over 3 million words. Features for automated testing, packaging and releasing round out a fully-featured development environment for IF.

Inform is free, with no strings attached. What you make with it is yours, to publish on your website, sell, or give to your friends. There's a vibrant community of users who welcome newcomers (and the app will help you find a high-traffic forum for discussions). Lastly, Inform is continuously maintained and developed. All bug reports are examined and acted on (and the app will show you how to post them).

## History

App Version  | Inform Version | Release Date | Description
------------ | -------------- | ------------ | :---------------------------------------
1.81.0-beta1 | 10.1.0 (beta)  | 2022-07-29   | Beta 1. Dark mode, Apple Silicon support.
1.68.1       | 6M62           | 2019-11-14   | Release with website bug fix.
1.67.1       | 6M62           | 2019-10-25   | macOS Catalina support.
1.65.1       | 6M62           | 2016-10-21   | macOS Sierra support. (Also another bug fix for 10.6.8 - Bug #1895)
1.64.1       | 6M62           | 2016-01-06   | Bugfixes (Fix for 10.6.8 support #1807, toolbar panel #1808, Syntax colouring #1815)
1.64.0       | 6M62           | 2015-12-24   | Includes new Testing panel, and support for Extension Projects
1.54.4       | 6L38           | 2014-11-21   | First Mac App Store version released
1.53         | 6L38           | 2014-09-23   | Experimental sandboxed version (getting closer to Mac App Store release, Distributed to testers to test if it works)
1.52         | 6L38           | 2014-09-18   | Fixed previous version, now signed properly and non-sandboxed.
1.51         | 6L38           | 2014-08-30   | Badly signed and sandboxed version
1.50         | 6L02           | 2014-05-07   | First update, modernising Inform

### Compiling Inform
Inform is currently compiled with XCode 13.4.1 on macOS Monterey (12.4)

### Licensing
See file 'COPYING'

------------------------------------------------
Toby Nelson, toby m nelson@gmail.com
