# The Inform App for macOS

## What's New
A new beta version of the Inform App is now available [here](https://github.com/TobyLobster/Inform/releases). The minimum requirement is now macOS 10.14.6 (Mojave). Users on older macOS versions can of course continue using previous versions from [here](http://inform7.com/downloads/).

- The launcher screen shows the latest News from the IFTF.
- Colour schemes have been introduced (see the new preferences pane).
- Support for Dark Mode.
- Support for *Basic Inform*.
- Fixes for skeins misdrawing in some cases.
- Apple Silicon native (while still supporting Intel Macs).
- A great deal of modernisation has gone on under the hood, but this still remains a work in progress.
- Support for Inform 6 projects has been removed.

Many thanks to MaddTheSane for a heroic number of modernisations, tweaks and fixes.

### Known Issues
- Release with winning node marked with '***' in Skein not currently working?

### Work in the Pipeline
- Build instructions.
- Updating to latest libraries.
- Dark mode across more views.
- Mac App Store Version.
- Longer term: Modernisation to Swift, and away from deprecated APIs.

## About Inform
Inform is a design system for interactive fiction based on natural language, a new medium of writing which came out of the "text adventure" games of the 1980s. It has been used by many leading writers of IF over the last twenty years, for projects ranging from historical reconstructions, through games, to art pieces, which have won numerous awards and competitions.

To learn more about the core of Inform, see [https://github.com/ganelson/inform](https://github.com/ganelson/inform). For more Inform resources, see [inform7.com](http://www.inform7.com).

Inform is free, with no strings attached. What you make with it is yours, to publish on your website, sell, or give to your friends. There's a vibrant community of users who welcome newcomers (and the app will help you find a high-traffic forum for discussions). Lastly, Inform is continuously maintained and developed. All bug reports are examined and acted on (and the app will show you how to post them).

## Version History

App Version  | Inform Version | Release Date | Description
------------ | -------------- | ------------ | :---------------------------------------
1.81.0&#8209;beta1 | 10.1.0&nbsp;(beta)  | 2022&#8209;07&#8209;30   | This is a Beta. Colour Schemes, Dark mode, Basic Inform, Apple Silicon native support.
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

### Building the Inform App.
This section is TODO.

Before building the Inform App, there are changes required to the XCode project files found in its submodules. I therefore need to document these for this section to be useful. I am investigating possible solutions for this issue.

Inform is currently being compiled with XCode (13.4.1) on macOS Monterey (12.4).

### Building a release of the Inform App
This section is TODO.

### Licensing
See file 'COPYING'

------------------------------------------------
Toby Nelson, toby m nelson@gmail.com
