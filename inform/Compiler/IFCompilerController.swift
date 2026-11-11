//
//  IFCompilerController.swift
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

import Cocoa
import WebKit

@objc @implementation extension IFCompilerTab {
    private final var _view: NSView?
    private final var _name: String?

    var view: NSView {
        get {
            return _view!
        }
        set {
            _view = newValue
        }
    }

    var name: String {
        get {
            return _name!
        }
        set {
            _name = newValue
        }
    }

    /// Zero until it's set, as in Objective-C
    var tabId: IFCompilerTabId = .tabReport
}

@objc @implementation extension IFCompilerController {
    /// Output from the compiler ends up here
    @IBOutlet private final var compilerResults: NSTextView?
    /// ...and is scrolled around by this thingmebob
    @IBOutlet private final var resultScroller: NSScrollView?

    /// Yin/yang?
    private final var _splitView: NSSplitView?
    /// Superview of split view
    @IBOutlet private final var superView: NSView?
    /// This scrolls around our parsed messages
    @IBOutlet private final var messageScroller: NSScrollView?
    /// ...and this actually displays them
    @IBOutlet private final var compilerMessages: NSOutlineView?

    /// This object receives our delegate messages
    weak var delegate: IFCompilerControllerDelegate?

    /// Project controller, held weakly, as it owns the pane
    private final weak var projectController: IFProjectController?
    private final var helper: IFWebViewHelper?
    /// The pane, held weakly, as it owns the errors page, which owns this
    private final weak var pane: IFProjectPane?

    /// Tabs
    private final var tabs: [IFCompilerTab] = []
    /// Currently selected tab
    private final var _selectedTabId: IFCompilerTabId = .tabInvalid
    private final var _currentWebView: WKWebView?

    // The subtask
    /// This is the actual compiler
    private final var _compiler: IFCompiler?
    /// The last problem URL returned by the compiler
    private final var lastProblemURL: NSURL?
    /// The overridden problems URL
    private final var overrideURL: NSURL?

    // Styles
    /// The attributes used to render various strings recognised by the parser
    private final var styles: [String: [NSAttributedString.Key: Any]] = [:]
    /// The position the highlighter has reached (see IFError.[hl])
    private final var highlightPos = 0
    /// Scans each line of output for its style and what it says
    private final let outputScanner = IFCompilerOutputScanner()

    // Error messages
    // (Objective-C arrays, so that the outline view is given the same objects for its items each time it asks)
    /// A list of the files that the compiler has reported errors on (this is how we group errors together by file)
    private final let errorFiles = NSMutableArray()
    /// A list of the error messages that the compiler has reported
    private final let errorMessages = NSMutableArray()
    /// Where cblorb has requested that the blorb file be copied
    private final var _blorbLocation: String?

    // MARK: - Styles

    class func defaultStyles() -> [NSAttributedString.Key: Any] {
        let indigoColor: NSColor
        if #available(macOS 10.15, *) {
            indigoColor = NSColor.systemIndigo
        } else {
            indigoColor = NSColor(named: "Compiler/Indigo")!
        }

        let bigFont = NSFont(name: "Monaco", size: 11.0)!
        let baseFont = bigFont
        let smallFont = bigFont
        let boldFont = NSFontManager.shared.convert(bigFont,
                                                    toHaveTrait: .boldFontMask)
        let italicFont = NSFontManager.shared.convert(boldFont,
                                                      toHaveTrait: .italicFontMask)

        let baseStyle: [NSAttributedString.Key: Any] = [.font: baseFont,
                                                        .foregroundColor: NSColor.textColor]

        let launchStyle: [NSAttributedString.Key: Any] = [.font: baseFont,
                                                          .foregroundColor: NSColor(named: "Compiler/Launch")!]

        let versionStyle: [NSAttributedString.Key: Any] = [.font: bigFont,
                                                           .foregroundColor: NSColor.textColor]

        let filenameStyle: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.textColor,
                                                            .font: boldFont]

        let messageStyle: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemGreen]
        let warningStyle: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemBlue,
                                                           .font: boldFont]
        let errorStyle: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor(named: "Compiler/DarkRed")!,
                                                         .font: boldFont]
        let fatalErrorStyle: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemRed,
                                                              .font: italicFont]
        let progressStyle: [NSAttributedString.Key: Any] = [.foregroundColor: indigoColor,
                                                            .font: smallFont]

        return [
            NSAttributedString.Key(IFStyleBase): baseStyle,
            NSAttributedString.Key(IFStyleLaunch): launchStyle,
            NSAttributedString.Key(IFStyleCompilerVersion): versionStyle,
            NSAttributedString.Key(IFStyleCompilerMessage): messageStyle,
            NSAttributedString.Key(IFStyleCompilerWarning): warningStyle,
            NSAttributedString.Key(IFStyleCompilerError): errorStyle,
            NSAttributedString.Key(IFStyleCompilerFatalError): fatalErrorStyle,
            NSAttributedString.Key(IFStyleFilename): filenameStyle,
            NSAttributedString.Key(IFStyleProgress): progressStyle,
        ]
    }

    // MARK: - Initialisation

    private final func registerHandlers() {
        if let compiler = _compiler {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(clearConsole(_:)),
                                                   name: .IFCompilerClearConsole,
                                                   object: compiler)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(started(_:)),
                                                   name: .IFCompilerStarting,
                                                   object: compiler)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(finished(_:)),
                                                   name: .IFCompilerFinished,
                                                   object: compiler)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(gotStdout(_:)),
                                                   name: .IFCompilerStdout,
                                                   object: compiler)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(gotStderr(_:)),
                                                   name: .IFCompilerStderr,
                                                   object: compiler)

            // Font size change
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(fontSizePreferenceChanged(_:)),
                                                   name: .IFPreferencesAppFontSizeDidChange,
                                                   object: IFPreferences.shared)
        }
    }

    private final func removeHandlers() {
        if let compiler = _compiler {
            NotificationCenter.default.removeObserver(self,
                                                      name: .IFCompilerClearConsole,
                                                      object: compiler)
            NotificationCenter.default.removeObserver(self,
                                                      name: .IFCompilerStarting,
                                                      object: compiler)
            NotificationCenter.default.removeObserver(self,
                                                      name: .IFCompilerFinished,
                                                      object: compiler)
            NotificationCenter.default.removeObserver(self,
                                                      name: .IFCompilerStdout,
                                                      object: compiler)
            NotificationCenter.default.removeObserver(self,
                                                      name: .IFCompilerStderr,
                                                      object: compiler)

            // Font size change
            NotificationCenter.default.removeObserver(self,
                                                      name: .IFPreferencesAppFontSizeDidChange,
                                                      object: nil)
        }
    }

    override init() {
        super.init()

        _compiler = IFCompiler()
        for (name, style) in type(of: self).defaultStyles() {
            styles[name.rawValue] = style as? [NSAttributedString.Key: Any]
        }
        outputScanner.delegate = self

        registerHandlers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    nonisolated public override func awakeFromNib() {
        // Nibs are loaded on the main thread
        MainActor.assumeIsolated {
            compilerResults?.textStorage?.delegate = self

            _splitView?.delegate = self
            adjustSplitView()

            messageScroller?.borderType = .noBorder

            resultScroller?.hasHorizontalScroller = true
            compilerResults?.maxSize = NSSize(width: 1e8, height: 1e8)
            compilerResults?.isHorizontallyResizable = true
            compilerResults?.isVerticallyResizable = true
            compilerResults?.textContainer?.widthTracksTextView = false
            compilerResults?.textContainer?.containerSize = NSSize(width: 1e8, height: 1e8)
            compilerResults?.backgroundColor = NSColor.textBackgroundColor
        }
    }

    // MARK: - Information

    @objc(setProjectController:withPane:)
    func setProject(_ pc: IFProjectController,
                    with thePane: IFProjectPane) {
        projectController = pc
        pane = thePane

        helper = IFWebViewHelper(projectController: projectController,
                                 with: pane)
    }

    // MARK: - Preferences

    @objc private final func fontSizePreferenceChanged(_ not: Notification) {
        if let currentWebView = _currentWebView {
            helper?.fontSizePreferenceChanged(currentWebView)
        }
    }

    // MARK: -

    var compiler: IFCompiler {
        get {
            return _compiler!
        }
        set {
            removeHandlers()

            _compiler = newValue
            registerHandlers()

            adjustSplitView()
        }
    }

    var inTest: IFInTest? {
        didSet {
            if let oldValue {
                for name in [Notification.Name.IFInTestStarting, .IFInTestFinished, .IFInTestStdout,
                             .IFInTestStderr] {
                    NotificationCenter.default.removeObserver(self, name: name, object: oldValue)
                }
            }
            if let inTest {
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(intestStarting(_:)),
                                                       name: .IFInTestStarting,
                                                       object: inTest)
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(intestFinished(_:)),
                                                       name: .IFInTestFinished,
                                                       object: inTest)
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(gotIntestStdout(_:)),
                                                       name: .IFInTestStdout,
                                                       object: inTest)
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(gotIntestStderr(_:)),
                                                       name: .IFInTestStderr,
                                                       object: inTest)
            }
        }
    }

    // MARK: - Compiler messages

    @objc private final func scrollToEnd() {
        if let compilerResults {
            compilerResults.scrollRangeToVisible(NSRange(location: compilerResults.textStorage?.length ?? 0,
                                                         length: 0))
        }
    }

    @objc(clearConsole:)
    func clearConsole(_ not: Notification?) {
        errorMessages.removeAllObjects()
        errorFiles.removeAllObjects()
        compilerMessages?.reloadData()

        clearTabViewsExcept(.tabConsole)

        compilerResults?.textStorage?.mutableString.setString("")
        highlightPos = 0
    }

    @objc private final func started(_ not: Notification) {
        overrideURL = nil
        _blorbLocation = nil
    }

    @objc private final func finished(_ not: Notification) {
        let exitCode = (not.userInfo?["exitCode"] as? NSNumber)?.int32Value ?? 0

        if let overrideURL {
            lastProblemURL = overrideURL
        }
        else {
            lastProblemURL = _compiler?.problemsURL as NSURL?
        }

        // Add to results
        compilerResults?.textStorage?.mutableString.append("\n")
        compilerResults?.textStorage?.mutableString.append(
            String(format: IFUtility.localizedString("Compiler finished with code %i"), exitCode))
        compilerResults?.textStorage?.mutableString.append("\n")
        adjustSplitView()

        // Log error
        if exitCode != 0 {
            switch exitCode {
            case SIGILL, SIGABRT, SIGBUS, SIGSEGV:
                NSLog("%@", String(format: IFUtility.localizedString("Compiler crashed with code %i"), exitCode))

            default:
                NSLog("%@", String(format: IFUtility.localizedString("Compilation failed with code %i"), exitCode))
            }
        }

        scrollToEnd()
    }

    @objc private final func gotStdout(_ not: Notification) {
        let data = not.userInfo?["string"] as? String ?? ""
        let style = not.userInfo?["style"] as? String
        let newString = NSAttributedString(string: data,
                                           attributes: style.flatMap { styles[$0] })

        compilerResults?.textStorage?.append(newString)
    }

    @objc private final func gotStderr(_ not: Notification) {
        let data = not.userInfo?["string"] as? String ?? ""
        let newString = NSAttributedString(string: data,
                                           attributes: styles[IFStyleBase])

        compilerResults?.textStorage?.append(newString)
    }

    // MARK: - intest support

    @objc private final func intestStarting(_ not: Notification) {
        let command = not.userInfo?["command"] as? String ?? ""
        let args = not.userInfo?["args"] as? [String] ?? []

        var message = ""
        message += IFUtility.localizedString("Launching: ")
        message += command
        message += " "
        for arg in args {
            message += arg
            message += " "
        }
        message += "\n"

        // Add to results
        let newString = NSAttributedString(string: message,
                                           attributes: styles[IFStyleBase])
        compilerResults?.textStorage?.append(newString)
    }

    @objc private final func intestFinished(_ not: Notification) {
        let exitCode = (not.userInfo?["exitCode"] as? NSNumber)?.int32Value ?? 0

        // Add to results
        compilerResults?.textStorage?.mutableString.append(
            String(format: IFUtility.localizedString("Intest finished with code %i"), exitCode))
        compilerResults?.textStorage?.mutableString.append("\n")

        // Log error
        if exitCode != 0 {
            switch exitCode {
            case SIGILL, SIGABRT, SIGBUS, SIGSEGV:
                NSLog("%@", String(format: IFUtility.localizedString("Intest crashed with code %i"), exitCode))

            default:
                NSLog("%@", String(format: IFUtility.localizedString("Intest failed with code %i"), exitCode))
            }
        }

        scrollToEnd()
    }

    @objc private final func gotIntestStdout(_ not: Notification) {
        let data = not.userInfo?["string"] as? String ?? ""
        let newString = NSAttributedString(string: data,
                                           attributes: styles[IFStyleBase])

        compilerResults?.textStorage?.append(newString)
    }

    @objc private final func gotIntestStderr(_ not: Notification) {
        let data = not.userInfo?["string"] as? String ?? ""
        let newString = NSAttributedString(string: data,
                                           attributes: styles[IFStyleCompilerError])

        compilerResults?.textStorage?.append(newString)
    }

    // MARK: - The error OutlineView

    @objc(addErrorForFile:atLine:withType:message:)
    func addError(forFile file: String,
                  atLine line: Int32,
                  withType type: IFLex,
                  message: String) {
        // Find the entry for this error message, if it exists. If not,
        // add this as a new file...
        var fileNum = errorFiles.index(of: file)

        if fileNum == NSNotFound {
            fileNum = errorFiles.count

            let fileItem = file as NSString
            errorFiles.add(fileItem)
            errorMessages.add(NSMutableArray())

            compilerMessages?.reloadData()
            compilerMessages?.reloadItem(fileItem,
                                         reloadChildren: true)

            compilerMessages?.expandItem(fileItem)
        }

        // Add an entry for this error message
        let fileMessages = errorMessages[fileNum] as! NSMutableArray
        let newMessage: NSArray = [message,
                                   NSNumber(value: line),
                                   NSNumber(value: Int32(bitPattern: type.rawValue)),
                                   NSNumber(value: fileNum)]
        fileMessages.add(newMessage)

        // Update the outline view
        compilerMessages?.reloadData()

        adjustSplitView()
    }

    @objc(outlineView:numberOfChildrenOfItem:)
    private final func outlineView(_ outlineView: NSOutlineView,
                                   numberOfChildrenOfItem item: Any?) -> Int {
        guard let item else {
            return errorFiles.count
        }

        let fileNum = errorFiles.indexOfObjectIdentical(to: item)

        if fileNum == NSNotFound {
            return 0
        }

        return (errorMessages[fileNum] as! NSMutableArray).count
    }

    @objc(outlineView:isItemExpandable:)
    private final func outlineView(_ outlineView: NSOutlineView,
                                   isItemExpandable item: Any?) -> Bool {
        guard let item else {
            return true
        }
        return errorFiles.indexOfObjectIdentical(to: item) != NSNotFound
    }

    @objc(outlineView:child:ofItem:)
    private final func outlineView(_ outlineView: NSOutlineView,
                                   child index: Int,
                                   ofItem item: Any?) -> Any? {
        guard let item else {
            return errorFiles[index]
        }

        let fileNum = errorFiles.indexOfObjectIdentical(to: item)

        if fileNum == NSNotFound {
            return nil
        }

        return (errorMessages[fileNum] as! NSMutableArray)[index]
    }

    @objc(outlineView:objectValueForTableColumn:byItem:)
    private final func outlineView(_ outlineView: NSOutlineView,
                                   objectValueFor tableColumn: NSTableColumn?,
                                   byItem item: Any?) -> Any? {
        if let file = item as? NSString {
            // Must be a filename
            let str = NSAttributedString(string: file.lastPathComponent,
                                         attributes: styles[IFStyleFilename])

            return str
        }

        // Is an array of the form message, line, type
        guard let item = item as? NSArray else {
            return nil
        }
        let message = item[0] as? String ?? ""
        let line = (item[1] as? NSNumber)?.int32Value ?? 0
        let type = IFLex(rawValue: UInt32(bitPattern: (item[2] as? NSNumber)?.int32Value ?? 0))

        var attr = styles[IFStyleCompilerMessage]

        switch type {
        case IFLexCompilerWarning:
            attr = styles[IFStyleCompilerWarning]

        case IFLexCompilerError:
            attr = styles[IFStyleCompilerError]

        case IFLexCompilerFatalError:
            attr = styles[IFStyleCompilerFatalError]

        default:
            break
        }

        let msg = String(format: "L%i: %@", line, message)
        let res = NSAttributedString(string: msg,
                                     attributes: attr)

        return res
    }

    @objc(outlineViewSelectionDidChange:)
    private final func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let compilerMessages,
              let obj = compilerMessages.item(atRow: compilerMessages.selectedRow) else {
            return // Nothing selected
        }

        var fileNum = errorFiles.indexOfObjectIdentical(to: obj)

        if fileNum != NSNotFound {
            return // File item selected
        }

        // obj is an array of the form [message, line, type]
        guard let msg = obj as? NSArray else {
            return
        }

        let line = (msg[1] as? NSNumber)?.int32Value ?? 0
        fileNum = (msg[3] as? NSNumber)?.intValue ?? 0

        // Send to the delegate
        delegate?.errorMessageHighlighted?(self,
                                           atLine: line,
                                           inFile: errorFiles[fileNum] as! String)
    }

    // MARK: - Other information

    private final func tabIndex(withTabId tabId: IFCompilerTabId) -> Int {
        for index in 0..<tabs.count {
            let tab = tabs[index]
            if tab.tabId == tabId {
                return index
            }
        }
        return NSNotFound
    }

    @objc(tabIdWithTabIndex:)
    func tabId(withTabIndex tabIndex: Int32) -> Int32 {
        let tab = tabs[Int(tabIndex)]
        return Int32(bitPattern: tab.tabId.rawValue)
    }

    private final func tabsContainsTabId(_ tabId: IFCompilerTabId) -> Bool {
        return tabIndex(withTabId: tabId) != NSNotFound
    }

    private final func replaceView(withTabId tabId: IFCompilerTabId,
                                   with aView: NSView) {
        let tabIndex = tabIndex(withTabId: tabId)
        if tabIndex != NSNotFound {
            let tab = tabs[tabIndex]
            tab.view = aView
            let tab2 = tabs[tabIndex]

            assert(tab2.view === aView, "Replace didn't work...")
        }
    }

    @discardableResult
    private final func makeTabViewItem(named tabName: String,
                                       with newView: NSView,
                                       tabId: IFCompilerTabId) -> IFCompilerTabId {
        let newTab = IFCompilerTab()
        newTab.name = tabName
        newTab.view = newView
        newTab.tabId = tabId

        tabs.append(newTab)

        delegate?.viewSetHasUpdated?(self)

        return newTab.tabId
    }

    @discardableResult
    private final func makeTab(for url: URL,
                               named tabName: String,
                               tabId: IFCompilerTabId) -> IFCompilerTabId {
        // Create a new web view
        let webView = helper!.createWebView(withFrame: superView?.frame ?? .zero)

        // Set delegate
        webView.navigationDelegate = delegate

        webView.load(URLRequest(url: url))

        // Add it to the list of tabs
        return makeTabViewItem(named: tabName,
                               with: webView,
                               tabId: tabId)
    }

    @objc(makeTabForFile:)
    func makeTab(forFile file: String) -> IFCompilerTabId {
        let type = (file as NSString).pathExtension.lowercased()
        let fileName = (file as NSString).lastPathComponent

        if type == "html" || type == "htm" {
            // Treat as a webkit URL
            return makeTab(for: URL(fileURLWithPath: file),
                           named: IFUtility.localizedString(fileName,
                                                            default: (fileName as NSString).deletingPathExtension,
                                                            table: "CompilerOutput"),
                           tabId: IFCompilerResultFiles.tabId(forFile: fileName))
        }
        else {
            // Create the new text view
            let textView = NSTextView(frame: superView?.frame ?? .zero)
            let scrollView = NSScrollView(frame: superView?.frame ?? .zero)

            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(width: 1e8, height: 1e8)
            textView.minSize = NSSize(width: 0.0, height: 0.0)
            textView.maxSize = NSSize(width: 1e8, height: 1e8)
            textView.isVerticallyResizable = true
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.width, .height]
            textView.isEditable = false
            textView.usesFindPanel = true

            var tabStops: [NSTextTab] = []
            for i in 0..<50 {
                let tab = NSTextTab(type: .leftTabStopType, location: CGFloat(20 * i))
                tabStops.append(tab)
            }
            let nameParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle

            nameParagraphStyle.headIndent = 20.0
            nameParagraphStyle.tabStops = tabStops

            // Load the data for the file
            let data = NSData(contentsOfFile: file) as Data? ?? Data()
            var textData = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            if textData == nil {
                textData = NSString(data: data, encoding: String.Encoding.isoLatin1.rawValue)
            }

            let attrString = NSMutableAttributedString(string: (textData ?? "") as String,
                                                       attributes: [.paragraphStyle: nameParagraphStyle,
                                                                    .font: NSFont(name: "Monaco", size: 11)!])
            textView.textStorage?.setAttributedString(attrString)

            // scrollView is the 'parent' of the textView
            scrollView.documentView = textView
            scrollView.autoresizingMask = [.width, .height]
            scrollView.hasHorizontalScroller = true
            scrollView.hasVerticalScroller = true

            // Add the tab
            return makeTabViewItem(named: IFUtility.localizedString(fileName,
                                                                    default: (fileName as NSString).deletingPathExtension,
                                                                    table: "CompilerOutput"),
                                   with: scrollView,
                                   tabId: IFCompilerResultFiles.tabId(forFile: fileName))
        }
    }

    @objc(showRuntimeError:)
    func showRuntimeError(_ errorURL: URL) {
        // Create a web view
        let webView = helper!.createWebView(withFrame: superView?.frame ?? .zero)
        webView.load(URLRequest(url: errorURL))

        if tabsContainsTabId(.tabRuntime) {
            // Replace the existing runtime error view
            replaceView(withTabId: .tabRuntime, with: webView)
        }
        else {
            // Add a new runtime error view
            makeTabViewItem(named: IFUtility.localizedString("Runtime errors"),
                            with: webView,
                            tabId: .tabRuntime)
        }

        // Switch to the runtime view
        switchToView(with: .tabRuntime)
    }

    @objc(showContentsOfFilesIn:fromPath:)
    func showContentsOfFiles(in files: FileWrapper,
                             fromPath path: String) {
        if !files.isDirectory {
            return // Nothing to do
        }

        // If there is a compiler-supplied problems file, add this to the tab view
        if let lastProblemURL {
            makeTab(for: lastProblemURL as URL,
                    named: IFUtility.localizedString("Problems.html",
                                                     default: "Problems",
                                                     table: "CompilerOutput"),
                    tabId: .tabReport)
        }

        // Enumerate across the files in the filewrapper that go in a tab view
        for key in IFCompilerResultFiles.filesToShow(of: files.fileWrappers.map { Array($0.keys) } ?? [],
                                                     showDebuggingLogs: IFPreferences.shared.showDebuggingLogs,
                                                     problemsURL: lastProblemURL as URL?) {
            makeTab(forFile: (path as NSString).appendingPathComponent(key))
        }

        switchToView(with: .tabReport)
    }

    @objc(clearTabViewsExcept:)
    func clearTabViewsExcept(_ exceptTabId: IFCompilerTabId) {
        var updated = false

        // Clear all views except the console view
        for index in stride(from: tabs.count - 1, through: 0, by: -1) {
            let tab = tabs[index]
            if tab.tabId != exceptTabId {
                tabs.remove(at: index)
                updated = true
            }
        }

        // Notify the delegate that the set of views has updated
        if updated {
            delegate?.viewSetHasUpdated?(self)
        }

        // Switch to the console view
        if _selectedTabId != .tabConsole {
            switchToView(with: .tabConsole)
        }
    }

    // MARK: - Delegate

    var blorbLocation: String? {
        return _blorbLocation
    }

    @objc(overrideProblemsURL:)
    func overrideProblemsURL(_ problemsURL: URL) {
        overrideURL = problemsURL as NSURL
    }

    private final func adjustSplitView() {
        var newFrame = messageScroller?.frame ?? .zero
        newFrame.size.height = 0
        messageScroller?.frame = newFrame

        var resultFrame = resultScroller?.frame ?? .zero

        resultFrame.size.height = (_splitView?.frame.size.height ?? 0) - newFrame.size.height - (_splitView?.dividerThickness ?? 0)
        resultScroller?.frame = resultFrame

        //    [splitView adjustSubviews];
    }

    var splitView: NSSplitView {
        get {
            return _splitView!
        }
        set {
            // Remember the new split view
            _splitView = newValue
            superView = newValue.superview

            newValue.autoresizingMask = [.width, .height]

            if !tabsContainsTabId(.tabConsole) {
                let newTab = IFCompilerTab()
                newTab.view = newValue
                newTab.name = IFUtility.localizedString("Compiler",
                                                        default: "Compiler",
                                                        table: "CompilerOutput")
                newTab.tabId = .tabConsole
                tabs.append(newTab)

                _selectedTabId = .tabConsole
            }
            else {
                adjustSplitView()
                replaceView(withTabId: .tabConsole,
                            with: newValue)
            }

            delegate?.viewSetHasUpdated?(self)
        }
    }

    // MARK: - Managing the set of views displayed by this object

    var selectedTabId: IFCompilerTabId {
        return _selectedTabId
    }

    var currentWebView: WKWebView? {
        return _currentWebView
    }

    @objc(switchToViewWithTabId:)
    func switchToView(with tabId: IFCompilerTabId) {
        let index = tabIndex(withTabId: tabId)

        // Check if available
        if index == NSNotFound {
            return
        }
        assert(tabs.count > index, "index too large")

        let tab = tabs[index]

        // ... or if we can't display anything
        guard let superView else {
            return
        }
        let activeView = superView.subviews[0]

        // Swap the view being displayed by this object for the view in auxViews
        let newView = tab.view
        if let webView = newView as? WKWebView {
            _currentWebView = webView
        }
        else {
            _currentWebView = nil
        }

        let rect = activeView.frame
        activeView.removeFromSuperview()
        superView.addSubview(newView)
        newView.frame = rect

        // Give focus to the new window
        if let splitView = newView as? NSSplitView {
            superView.window?.makeFirstResponder(splitView.subviews[1])
        }
        else {
            superView.window?.makeFirstResponder(newView)
        }

        _selectedTabId = tab.tabId
        //NSAssert(selectedTabId != IFTabInvalid, @"Invalid tab selected");

        // Inform the delegate of the change
        delegate?.compiler?(self,
                            switchedToView: Int32(index))
    }

    func switchToSplitView() {
        switchToView(with: .tabConsole)
    }

    var viewTabs: [IFCompilerTab] {
        return tabs
    }
}

// The controller's header conforms to NSTextStorageDelegate, whose methods an @implementation doesn't take
extension IFCompilerController {
    // MARK: - Dealing with highlighting of the compiler output

    @objc(textStorage:didProcessEditing:range:changeInLength:)
    public func textStorage(_ storage: NSTextStorage,
                            didProcessEditing editedMask: NSTextStorageEditActions,
                            range editedRange: NSRange,
                            changeInLength delta: Int) {
        // Set the text to the base style
        storage.beginEditing()

        // For each line since highlightPos...
        let str = storage.string as NSString
        let len = str.length

        var newlinePos: Int

        repeat {
            newlinePos = -1

            for x in stride(from: highlightPos, to: len, by: 1) {
                if str.character(at: x) == unichar(UInt8(ascii: "\n")) {
                    newlinePos = x
                    break
                }
            }

            if newlinePos == -1 {
                break
            }

            // ... set the style appropriately
            let lineRange = NSRange(location: highlightPos, length: (newlinePos - highlightPos) + 1)
            let newStyle = outputScanner.style(forLine: str.substring(with: lineRange))

            if let newStyle, let attributes = styles[newStyle] {
                storage.addAttributes(attributes,
                                      range: lineRange)
            }

            highlightPos = newlinePos + 1
        } while newlinePos != -1

        // Finish up
        storage.endEditing()

        RunLoop.current.perform(#selector(scrollToEnd),
                                target: self,
                                argument: nil,
                                order: 128,
                                modes: [.default])
    }
}

// What the compiler's output says, which the class extension in Objective-C took the protocol for
extension IFCompilerController: IFCompilerOutputScannerDelegate {
    // MARK: - What the compiler's output says

    @objc(outputScanner:hasProgress:message:)
    public func outputScanner(_ scanner: IFCompilerOutputScanner,
                              hasProgress percentage: Int32,
                              message: String?) {
        _compiler?.progress.percentage = CGFloat(percentage)
        if let message {
            _compiler?.progress.message = message
        }
    }

    @objc(outputScanner:hasEndText:)
    public func outputScanner(_ scanner: IFCompilerOutputScanner,
                              hasEndText endText: String) {
        _compiler?.endTextString = endText
    }

    @objc(outputScanner:addErrorForFile:atLine:withType:message:)
    public func outputScanner(_ scanner: IFCompilerOutputScanner,
                              addErrorForFile file: String,
                              atLine line: Int32,
                              withType type: IFLex,
                              message: String) {
        addError(forFile: file,
                 atLine: line,
                 withType: type,
                 message: message)
    }

    @objc(outputScanner:overrideProblemsURL:)
    public func outputScanner(_ scanner: IFCompilerOutputScanner,
                              overrideProblemsURL problemsURL: URL) {
        overrideProblemsURL(problemsURL)
    }

    @objc(outputScanner:copyBlorbTo:)
    public func outputScanner(_ scanner: IFCompilerOutputScanner,
                              copyBlorbTo location: String) {
        _blorbLocation = location
    }
}
