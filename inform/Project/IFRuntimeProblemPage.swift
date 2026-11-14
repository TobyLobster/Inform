//
//  IFRuntimeProblemPage.swift
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFRuntimeProblemPage.h.
//

import Foundation

/// Writes a page at the URL given saying that the app has no page for a run-time problem, and gives the URL, or nil
/// if it can't be written. The problem's name is as the story wrote it, so the characters HTML takes as markup are
/// escaped.
private func writePageForUnknownProblem(_ problem: String, to url: URL) -> URL? {
    let name = problem.replacingOccurrences(of: "&", with: "&amp;")
                      .replacingOccurrences(of: "<", with: "&lt;")
                      .replacingOccurrences(of: ">", with: "&gt;")
    let html = """
        <html><head><meta charset="UTF-8"><meta name="color-scheme" content="light dark">
        <title>Run-time problem \(name)</title></head>
        <body><h1>Run-time problem</h1>
        <p>The story reported the run-time problem \(name), which Inform has no page about.</p></body></html>

        """
    do {
        try html.write(to: url, atomically: true, encoding: .utf8)
    } catch {
        return nil
    }
    return url
}

@objc @implementation extension IFRuntimeProblemPage {
    private final var errorURL: NSURL?
    private final var _markdownPath: String?
    private final let internalDirectory: String
    /// Where the page is written, for a problem the app has no page for or one with a markdown file. Each page has its
    /// own file, so that another project's problem doesn't replace it there, to be shown when the page is reloaded.
    private final let temporaryPageURL: NSURL

    init(problem error: String,
         inDirectory directory: String?,
         materialsDirectory: String?,
         internalDirectory: String) {
        self.internalDirectory = internalDirectory
        let temporaryPageURL = IFUtility.temporaryDirectoryURL()
            .appendingPathComponent("RuntimeProblem-\(UUID().uuidString).html")
        self.temporaryPageURL = temporaryPageURL as NSURL
        if let directory = directory as NSString? {
            let errorFile = "\(error).md"
            if directory.starts(withCaseInsensitive: "Internal/") {
                // If directory starts with "Internal/" then resolve the path to inside the internal directory
                _markdownPath = ((internalDirectory as NSString).appendingPathComponent(directory.substring(from: 9)) as NSString).appendingPathComponent(errorFile)
            } else if directory.starts(withCaseInsensitive: "Materials/") {
                _markdownPath = materialsDirectory.map {
                    (($0 as NSString).appendingPathComponent(directory.substring(from: 10)) as NSString).appendingPathComponent(errorFile)
                }
            } else {
                // Otherwise the directory is given in full
                _markdownPath = directory.appendingPathComponent(errorFile)
            }
        } else {
            // If no directory is present, then redirect using old method (looks for a regular resource within the App).

            // The file that might contain the error
            let errorFile = "RTP_\(error)"

            // See if the file exists
            if Bundle.main.path(forResource: errorFile, ofType: "html") != nil {
                // This URL is where the error file will reside
                errorURL = NSURL(string: "inform:/\(errorFile).html")
            } else {
                // The error file cannot be found: show a page saying so
                NSLog("Warning: run-time error file '%@.html' not found", errorFile)
                errorURL = writePageForUnknownProblem(error, to: temporaryPageURL) as NSURL?
            }
        }

        super.init()
    }

    var appPageURL: URL? {
        return errorURL as URL?
    }

    var markdownPath: String? {
        return _markdownPath
    }

    var pageURL: URL? {
        if _markdownPath != nil {
            return temporaryPageURL as URL
        }
        return appPageURL
    }

    @MainActor @objc(makePageFromMarkdownWithInBuild:settings:)
    func makePageFromMarkdown(with inBuild: IFInBuild,
                              settings: IFCompilerSettings) {
        if let markdownPath = _markdownPath, let htmlURL = pageURL {
            // Run inbuild to convert the markdown file to HTML. When that fails, inbuild writes a page about the
            // error there instead, which is shown in its place.
            let internalURL = URL(fileURLWithPath: internalDirectory)
            inBuild.execute(forConvertingMarkdown: markdownPath,
                            toHTML: htmlURL.path,
                            withInternal: internalURL,
                            settings: settings)
        }
    }
}
