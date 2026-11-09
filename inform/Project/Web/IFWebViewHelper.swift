//
//  IFWebViewHelper.swift
//  Inform
//
//  Created by Toby Nelson on 04/05/2023.
//  Translated from Objective-C in November 2026. The interface is still IFWebViewHelper.h.
//

import Cocoa
import UniformTypeIdentifiers
import WebKit

/// The files in the app's resources (top level, or the localised folder), by their names in lower case, made the
/// first time they're needed
private let resourcePathsByLowercaseName: [String: String] = {
    var paths = [String: String]()
    let bundle = Bundle.main
    guard let resourcePath = bundle.resourcePath else {
        return paths
    }
    let localisedFolder = bundle.preferredLocalizations.first.flatMap {
        ($0 as NSString).appendingPathExtension("lproj")
    }
    var folders = [resourcePath]
    if let localisedFolder {
        // Added last, so localised files take precedence
        folders.append((resourcePath as NSString).appendingPathComponent(localisedFolder))
    }
    for folder in folders {
        for name in (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [] {
            paths[name.lowercased()] = (folder as NSString).appendingPathComponent(name)
        }
    }
    return paths
}()

@objc @implementation extension IFWebViewHelper {
    private final weak var projectController: IFProjectController?
    private final weak var pane: IFProjectPane?

    private final let genericError: NSError

    // MARK: - Initialisation

    @objc(initWithProjectController:withPane:)
    init(projectController theProjectController: IFProjectController?,
         with newPane: IFProjectPane?) {
        projectController = theProjectController
        pane = newPane

        genericError = NSError(domain: INFORM_ERROR_DOMAIN, code: 0, userInfo: nil)

        super.init()
    }

    func createWebView(withFrame frame: CGRect) -> WKWebView {
        // Create the web view for the documentation tab

        // First the configuration:
        let config = WKWebViewConfiguration()

        // The unit tests' web views keep their website data in memory, not in the user's Library
        if IFUtility.isHostingUnitTests {
            config.websiteDataStore = .nonPersistent()
        }

        // Handle 'inform:' scheme
        config.setURLSchemeHandler(self, forURLScheme: "inform")
        config.setURLSchemeHandler(self, forURLScheme: "source")
        config.setURLSchemeHandler(self, forURLScheme: "skein")
        config.setURLSchemeHandler(self, forURLScheme: "library")

        // We recieve messages from Javascript
        config.userContentController.add(self, name: "scriptHandler")

        // We inject Javascript to post appropriate messages
        let resourceURL = Bundle.main.url(forResource: "messages_to_objc", withExtension: "js")
        let javascriptTemplate = resourceURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

        // We inject Javascript to initially resize based on font size preference
        let fontSizeMultiplier = Float(IFPreferences.shared.appFontSizeMultiplier)
        let js = String(format: "window.addEventListener(\"load\",function () { document.body.style.zoom = '%.2f'; }, false);",
                        fontSizeMultiplier)

        // Inject both the message template and the font size Javascript
        let javascriptInjection = js + javascriptTemplate
        let userScript = WKUserScript(source: javascriptInjection,
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: true)
        config.userContentController.addUserScript(userScript)

        // Javascript code like the following now posts a message to us that we recieve in Swift land:
        //      window.webkit.messageHandlers.scriptHandler.postMessage(["functionName", "param1", "param2"]):

        // Create the view itself
        let wView = WKWebView(frame: frame, configuration: config)
        wView.autoresizingMask = [.width, .height]

        // Set delegates
        wView.uiDelegate = self

        return wView
    }

    // MARK: - WKURLSchemeHandler

    private final func url(fromLibraryURL url: URL?, frameURL: URL?) -> URL? {
        // Replace the "library:" prefix of the URL string with the URL for the enclosing document
        // ie. Transform:
        // Link URL: library:/resources/Extensions/Emily%20Short/Complex%20Listing-v10.zip?id=0
        // FrameURL: https://ganelson.github.io/inform-public-library/v11/
        // Combine into proper URL: https://ganelson.github.io/inform-public-library/v11/resources/Extensions/Emily%20Short/Complex%20Listing-v10.zip?id=0

        if let frameURL, var relativeString = (url as NSURL?)?.resourceSpecifier {
            // Remove leading scheme, i.e. 'library:'

            // Remove any leading forward slashes
            while relativeString.hasPrefix("/") {
                relativeString = (relativeString as NSString).substring(from: 1)
            }
            return URL(string: relativeString, relativeTo: frameURL)?.absoluteURL
        }
        return nil
    }

    private final func explodeString(_ string: String,
                                     innerGlue: String,
                                     outerGlue: String) -> [String: String] {
        // Explode based on outer glue
        let firstExplode = string.components(separatedBy: outerGlue)

        // Explode based on inner glue
        var returnDictionary = [String: String](minimumCapacity: firstExplode.count)
        for part in firstExplode {
            let secondExplode = part.components(separatedBy: innerGlue)
            if secondExplode.count == 2 {
                returnDictionary[secondExplode[0]] = secondExplode[1]
            }
        }
        return returnDictionary
    }

    @objc(webView:startURLSchemeTask:)
    func webView(_ webView: WKWebView,
                 start task: any WKURLSchemeTask) {
        guard let customURL = task.request.url else {
            return
        }

        if customURL.scheme == "inform" {
            var mimeType: String?
            var error: NSError?
            if let data = loadData(forInformURL: customURL,
                                   returningMimeType: &mimeType,
                                   returningError: &error) {
                let response = URLResponse(url: customURL,
                                           mimeType: mimeType,
                                           expectedContentLength: data.count,
                                           textEncodingName: nil)
                task.didReceive(response)
                task.didReceive(data)
                task.didFinish()
            } else if let error {
                task.didFailWithError(error)
            } else {
                task.didFailWithError(genericError)
            }
        } else if customURL.scheme == "source" {
            // Format is 'source file name#line number'
            guard let decoded = IFUtility.decodeSourceSchemeURL(customURL) else {
                task.didFailWithError(genericError)
                return
            }
            let project = projectController?.document as? IFProject
            guard let results = project?.redirectLinks(toExtensionSourceCode: decoded),
                  let sourceFile = results[0] as? String,
                  let lineNumber = (results[1] as? NSNumber)?.intValue else {
                task.didFailWithError(genericError)
                return
            }

            if projectController?.selectSourceFile(sourceFile) != true {
                task.didFailWithError(genericError)
                return
            }

            if lineNumber >= 0 {
                projectController?.move(toSourceFileLine: lineNumber)
            }
            projectController?.removeHighlights(of: .error)
            projectController?.highlightSourceFileLine(lineNumber,
                                                       inFile: sourceFile,
                                                       style: .error)

            // Finished
            task.didFailWithError(genericError)
            return
        } else if customURL.scheme == "skein" {
            // Format is e.g. 'skein:1003?case=B'
            guard let results = IFUtility.decodeSkeinSchemeURL(customURL) else {
                task.didFailWithError(genericError)
                return
            }
            let testCase = results[0]
            let formatter = NumberFormatter()
            let skeinNodeId = formatter.number(from: results[1])?.uintValue ?? 0

            // Move to the appropriate place in the file
            if projectController?.showTestCase(testCase, skeinNode: skeinNodeId) != true {
                NSLog("Can't select test case '%@'", testCase)
                task.didFailWithError(genericError)
                return
            }

            // Finished
            task.didFailWithError(genericError)
            return
        } else if customURL.scheme == "library" {
            // We have found a "library:" URL. These are used for links that will install an
            // extension from the public library. Clicking on one starts the installation.
            let mgr = IFExtensionsManager.sharedNaturalInform
            let url = webView.url
            let frameURL = IFUtility.publicLibraryURL()
            //
            // Transform:
            // FrameURL: https://ganelson.github.io/inform-public-library/v11/
            // Link URL: library:/resources/Extensions/Emily%20Short/Complex%20Listing-v10.zip?id=0
            // Combine into proper URL: https://ganelson.github.io/inform-public-library/v11/resources/Extensions/Emily%20Short/Complex%20Listing-v10.zip?id=0
            //
            if let newURL = self.url(fromLibraryURL: url, frameURL: frameURL) {
                // Query at the end of the URL may have id=<number> on the end
                let queryDict = explodeString((url as NSURL?)?.query ?? "",
                                              innerGlue: "=",
                                              outerGlue: "&")
                let javascriptId = queryDict["id"]

                _ = mgr.downloadAndInstallExtension(newURL,
                                                    window: webView.window,
                                                    notifyDelegate: projectController,
                                                    javascriptId: javascriptId)
            } else {
                NSLog("URL '%@' could not be transformed using frameURL '%@'",
                      url?.absoluteString ?? "(null)", frameURL?.absoluteString ?? "(null)")
            }
            task.didFailWithError(genericError)
            return
        }
    }

    @objc(webView:stopURLSchemeTask:)
    func webView(_ webView: WKWebView,
                 stop urlSchemeTask: any WKURLSchemeTask) {
        // Nothing to do
        return
    }

    /// Finds a file in the app's resources (top level, or the localised folder) ignoring case.
    /// Links written by the compiler can differ in case from the file names (inform:/wi_9_1.html
    /// for en.lproj/WI_9_1.html), and Bundle lookups are case-sensitive.
    private final func caseInsensitiveResourcePath(_ relativePath: String) -> String? {
        if (relativePath as NSString).pathComponents.count != 1 {
            return nil
        }
        return resourcePathsByLowercaseName[relativePath.lowercased()]
    }

    private final func loadData(forInformURL url: URL,
                                returningMimeType mimeType: inout String?,
                                returningError error: inout NSError?) -> Data? {
        // A URL with no path, such as "inform:", or "inform:file.html" with no slash, asks for the resources
        var urlPath = (url as NSURL).path ?? ""
        let host = (url as NSURL).host
        var path: String?

        // Remove any initial '/', to cope with "inform://..."
        if urlPath.hasPrefix("/") {
            urlPath = (urlPath as NSString).substring(from: 1)
        }
        let components = (urlPath as NSString).pathComponents

        // Give nothing outside the resources, the project's materials or the documentation folder (a URL's path can go
        // up out of them, as NSURL decodes "..%2F")
        if components.contains("..") {
            error = NSError(domain: NSURLErrorDomain,
                            code: NSURLErrorNoPermissionsToReadFile,
                            userInfo: [NSURLErrorFailingURLErrorKey: url])
            return nil
        }

        // Accept either the host or the path specifier containing 'extensions'
        let hostIsExtensions = host?.lowercased() == "extensions"
        let firstComponentIsExtensions = components.count > 1 && components[0].lowercased() == "extensions"
        if hostIsExtensions || firstComponentIsExtensions {
            let project = projectController?.document as? IFProject

            if let project, project.useNewExtensions {
                // Get the project's materials folder
                path = project.materialsDirectoryURL?.path

                // Add "Extensions" if needed
                if hostIsExtensions && !firstComponentIsExtensions {
                    path = path.map { ($0 as NSString).appendingPathComponent("Extensions") }
                }
            } else {
                // Get external Documentation folder
                path = IFUtility.pathForInformExternalDocumentation()
            }

            for pathComponent in components {
                path = path.map { ($0 as NSString).appendingPathComponent(pathComponent) }
            }

            // Check if the file exists
            if let existingPath = path, !FileManager.default.fileExists(atPath: existingPath) {
                path = nil
            }

            // The Index links to an extension's documentation as Documentation/<author>/<title>.html,
            // but Inform writes the page to Reserved/Documentation/<author>/<title>-v<version>/index.html
            if path == nil, let project, project.useNewExtensions {
                var parts = components
                if firstComponentIsExtensions {
                    parts = Array(components[1...])
                }
                if parts.count == 3 &&
                   parts[0].lowercased() == "documentation" &&
                   (parts[2] as NSString).pathExtension == "html" {
                    path = IFUtility.documentationPage(forExtensionTitled: (parts[2] as NSString).deletingPathExtension,
                                                       author: parts[1],
                                                       inMaterialsPath: project.materialsDirectoryURL?.path ?? "")
                }
            }
        } else {
            // Try using Inform Core external directory (if preference set)
            let prefs = IFPreferences.shared
            if prefs.useExternalInformCoreDirectory {
                // D/resources/App HTML
                // First look for resource in external directory, and if that fails, try the en.lproj directory
                let appHTML = ((prefs.externalInformCoreDirectory as NSString)
                                  .appendingPathComponent("Resources") as NSString)
                                  .appendingPathComponent("App HTML") as NSString
                var externalPath = appHTML.appendingPathComponent(urlPath)
                if !FileManager.default.fileExists(atPath: externalPath) {
                    externalPath = (appHTML.appendingPathComponent("en.lproj") as NSString)
                                       .appendingPathComponent(urlPath)
                    if !FileManager.default.fileExists(atPath: externalPath) {
                        NSLog("Warning: (Trying External Inform Core Directory) When trying to resolve URL '%@' I converted it to filepath '%@', but this file was not found here.\n",
                              url as NSURL, externalPath)
                    } else {
                        path = externalPath
                    }
                } else {
                    path = externalPath
                }
            }

            if path == nil {
                // Try using pathForResource:ofType:
                // Advantage of this is that it will allow for localisation at some point in the future
                let resourcePath = urlPath as NSString
                path = Bundle.main.path(forResource: (resourcePath.lastPathComponent as NSString).deletingPathExtension,
                                        ofType: resourcePath.pathExtension,
                                        inDirectory: resourcePath.deletingLastPathComponent)
            }

            if path == nil {
                path = caseInsensitiveResourcePath(urlPath)
            }
        }

        if path == nil {
            // Check if the file is in an asset catalog.
            var assetCheckPath = (urlPath as NSString).deletingPathExtension
            if (assetCheckPath as NSString).ends(withCaseInsensitive: "@2x") {
                assetCheckPath = (assetCheckPath as NSString).replacing("@2x", with: "")
            }

            if let img = NSImage(named: assetCheckPath) {
                //Just output TIFF: it uses the least amount of code:
                let urlData = img.tiffRepresentation

                //Which means a TIFF MIME type. Regardless of extension.
                mimeType = "image/tiff"
                return urlData
            }
        }

        if path == nil {
            // If that fails, then just append to the resourcePath of the main bundle
            path = Bundle.main.resourcePath.map { $0 + "/" + urlPath }
        }

        // Check that this is the right kind of URL for us
        guard let path, url.scheme == "inform" else {
            // Doh - not a valid inform: URL
            error = NSError(domain: NSURLErrorDomain,
                            code: NSURLErrorBadURL,
                            userInfo: [NSURLErrorFailingURLErrorKey: url])
            return nil
        }

        // Check that the file exists and is not a directory
        var isDir: ObjCBool = true
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            isDir = true
        }

        if isDir.boolValue {
            error = NSError(domain: NSURLErrorDomain,
                            code: NSURLErrorFileDoesNotExist,
                            userInfo: [NSURLErrorFailingURLErrorKey: url])
            return nil
        }

        // Load up the data
        guard let urlData = NSData(contentsOfFile: path) as Data? else {
            error = NSError(domain: NSURLErrorDomain,
                            code: NSURLErrorCannotOpenFile,
                            userInfo: [NSURLErrorFailingURLErrorKey: url])
            return nil
        }

        // Work out the MIME type
        let pathExtension = (path as NSString).pathExtension
        var ourType = UTType(filenameExtension: pathExtension,
                             conformingTo: .data)?.preferredMIMEType

        if ourType == nil {
            ourType = "text/html"
            if pathExtension == "gif" {
                ourType = "image/gif"
            } else if pathExtension == "jpeg" ||
                      pathExtension == "jpg" {
                ourType = "image/jpeg"
            } else if pathExtension == "png" {
                ourType = "image/png"
            } else if pathExtension == "tiff" ||
                      pathExtension == "tif" {
                ourType = "image/tiff"
            }
        }

        // Create the response
        mimeType = ourType
        error = nil
        return urlData
    }

    // MARK: - WKScriptMessageHandler methods

    @objc(userContentController:didReceiveScriptMessage:)
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        // Ignore a message that isn't a list of strings, which no page's script posts
        guard let list = message.body as? [String] else {
            return
        }

        //NSLog("%@", list)

        // Check for correct number of parameter required
        let commands: [String: Int] = ["selectView": 1,
                                       "confirmAction": 0,
                                       "install": 1,
                                       "modernise": 1,
                                       "uninstall": 1,
                                       "test": 3,
                                       "createNewProject": 2,
                                       "pasteCode": 1,
                                       "openFile": 1,
                                       "openURL": 1]
        if list.count == 0 {
            return
        }
        guard let parameters = commands[list[0]] else {
            return
        }
        if list.count <= parameters {
            return
        }
        if list[0] == "selectView" {
            selectView(list[1])
        } else if list[0] == "confirmAction" {
            confirmAction()
        } else if list[0] == "install" {
            install(list[1])
        } else if list[0] == "uninstall" {
            uninstall(list[1])
        } else if list[0] == "modernise" {
            modernise(list[1])
        } else if list[0] == "test" {
            test(list[1], command: list[2], testcase: list[3])
        } else if list[0] == "createNewProject" {
            createNewProject(list[1],
                             story: list[2])
        } else if list[0] == "pasteCode" {
            pasteCode(list[1])
        } else if list[0] == "openFile" {
            openFile(list[1])
        } else if list[0] == "openURL" {
            openUrl(list[1])
        }
    }

    // MARK: - Script messages

    func selectView(_ view: String) {
        let view = view.lowercased()

        if view == "source" {
            projectController?.sourcePane?.selectView(of: .sourcePane)
        } else if view == "error" {
            pane?.selectView(of: .errorPane)
        } else if view == "game" {
            pane?.selectView(of: .gamePane)
        } else if view == "documentation" {
            pane?.selectView(of: .documentationPane)
        } else if view == "index" {
            pane?.selectView(of: .indexPane)
        } else if view == "skein" {
            pane?.selectView(of: .skeinPane)
        } else {
            // Other view types are not supported at present
        }
    }

    private final func confirmAction() {
        // Install/Uninstall the extension that was last run through inbuild
        projectController?.confirmInbuildAction()
    }

    private final func install(_ extension: String) {
        // Install the extension
        projectController?.installExtension(`extension`)
    }

    private final func modernise(_ extension: String) {
        // Modernise the extension
        projectController?.moderniseExtension(`extension`)
    }

    private final func uninstall(_ extension: String) {
        // Install the extension
        projectController?.uninstallExtension(`extension`)
    }

    private final func test(_ extension: String,
                            command: String,
                            testcase: String) {
        // Test the extension
        projectController?.testExtension(`extension`,
                                         command: command,
                                         testcase: testcase)
    }

    func createNewProject(_ title: String,
                          story: String) {
        let title = IFUtility.unescapeString(title)
        let story = IFUtility.unescapeString(story)

        (NSApp.delegate as? IFAppDelegate)?.createNewProject(title,
                                                              story: story)
    }

    func pasteCode(_ code: String) {
        projectController?.sourcePane?.sourcePage.pasteSourceCode(IFUtility.unescapeString(code))
    }

    private final func openFile(_ filename: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: filename))

//        let dir = (filename as NSString).deletingLastPathComponent
//        NSWorkspace.shared.selectFile(filename,
//                                      inFileViewerRootedAtPath: dir)
    }

    func openUrl(_ url: String) {
        if !(URL(string: url).map { NSWorkspace.shared.open($0) } ?? false) {
            NSLog("Could not open URL: %@", url)
        }
    }

    // MARK: - Preferences

    func fontSizePreferenceChanged(_ wView: WKWebView) {
        let fontSizeMultiplier = Float(IFPreferences.shared.appFontSizeMultiplier)
        let js = String(format: "document.body.style.zoom = '%.2f'", fontSizeMultiplier)
        wView.evaluateJavaScript(js, completionHandler: nil)
    }
}

// The helper's header conforms to WKUIDelegate, whose optional methods an @implementation doesn't take
extension IFWebViewHelper {
    // MARK: - WKUIDelegate

    @objc(webView:runJavaScriptAlertPanelWithMessage:initiatedByFrame:completionHandler:)
    public func webView(_ webView: WKWebView,
                        runJavaScriptAlertPanelWithMessage message: String,
                        initiatedByFrame frame: WKFrameInfo,
                        completionHandler: @escaping @MainActor @Sendable () -> Void) {
        let alert = NSAlert()
        alert.messageText = IFUtility.localizedString("JavaScript Alert")
        alert.informativeText = message
        alert.addButton(withTitle: IFUtility.localizedString("Continue"))
        alert.runModal()

        completionHandler()
    }
}
