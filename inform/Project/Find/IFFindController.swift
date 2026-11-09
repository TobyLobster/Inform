//
//  IFFindController.swift
//  Inform
//
//  Created by Andrew Hunter on 05/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFFindController.h.
//

import Cocoa

private let IFFindHistoryPref = "IFFindHistory"
private let IFReplaceHistoryPref = "IFReplaceHistory"

private let FIND_HISTORY_LENGTH = 30

/// The shared find window controller
private var sharedController: IFFindController?

@objc @implementation extension IFFindController {
    // The components of the find dialog
    @IBOutlet private final var findPhrase: NSComboBox?                         // The phrase to search for
    @IBOutlet private final var replacePhrase: NSComboBox?                      // The phrase to replace it with

    // Ignore case radio button
    @IBOutlet private final var ignoreCase: NSButton?                           // The 'ignore case' checkbox

    // Pull down menu of how to search
    /// The 'contains/begins with/complete word/regexp' pop-up button
    @IBOutlet private final var searchType: NSPopUpButton?
    /// Choices for the type of object to find
    @IBOutlet private final var containsItem: NSMenuItem?
    @IBOutlet private final var beginsWithItem: NSMenuItem?
    @IBOutlet private final var completeWordItem: NSMenuItem?
    @IBOutlet private final var regexpItem: NSMenuItem?

    // Buttons
    @IBOutlet private final var next: NSButton?
    @IBOutlet private final var previous: NSButton?
    @IBOutlet private final var replaceAndFind: NSButton?
    @IBOutlet private final var replace: NSButton?
    @IBOutlet private final var findAll: NSButton?
    @IBOutlet private final var replaceAll: NSButton?

    // Parent view to position extra content
    @IBOutlet private final var auxViewPanel: NSView?                           // The auxilary view panel

    // The regular expression help view
    @IBOutlet private final var regexpHelpView: NSView?                         // The view containing information about regexps

    // The 'find all' views
    @IBOutlet private final var foundNothingView: NSView?                       // The view to show if we don't find any matches
    @IBOutlet private final var findAllView: NSView?                            // The main 'find all' view
    @IBOutlet private final var findAllTable: NSTableView?                      // The 'find all' results table
    @IBOutlet private final var findCountText: NSTextField?                     // Text of how many results we have
    private final var borders: CGFloat = 0                                      // Height of the window with the find all view open, but without the results table. A constant.

    // Things we've searched for
    private final var replaceHistory: [Any]                                     // The 'replace' history
    private final var findHistory: [Any]                                        // The 'find' history
    private final var defaults: UserDefaults?                                   // Where the histories are kept
    private final var lastSearch: String?                                       // The last phrase that was searched for
    private final var lastSearchType: NSMenuItem?                               // The last search type that was searched with
    private final var lastSearchIgnoreCase = false                              // The last searches 'ignore case' flag

    private final var findAllResults: [IFFindResult] = []                       // The 'find all' results view
    private final var findAllCount = 0                                          // Used to generate the identifier
    private final var findIdentifier: Any?                                      // The current find all identifier

    // Auxiliary views
    private final var auxView: NSView?                                          // The auxiliary view that is being displayed
    private final var winFrame = NSRect.zero                                    // The default window frame

    // The delegate
    /// The delegate that we've chosen to work with
    private final weak var activeDelegate: IFFindDelegate?

    // MARK: - Initialisation

    @objc(sharedFindController) class func shared() -> IFFindController {
        if let sharedController {
            return sharedController
        }
        let controller = IFFindController(defaults: UserDefaults.standard)
        sharedController = controller
        return controller
    }

    init(defaults theDefaults: UserDefaults) {
        defaults = theDefaults

        // Get the find/replace history
        findHistory = theDefaults.object(forKey: IFFindHistoryPref) as? [Any] ?? []
        replaceHistory = theDefaults.object(forKey: IFReplaceHistoryPref) as? [Any] ?? []

        // The nib is named by windowNibName, as a Swift initialiser can't call initWithWindowNibName:
        super.init(window: nil)

        // Get notifications about when the main window changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(mainWindowChanged(_:)),
                                               name: NSWindow.didBecomeMainNotification,
                                               object: nil)
    }

    // Swift needs this, as NSWindowController's is required. The Objective-C inherited it, starting with nothing set.
    public required init?(coder: NSCoder) {
        replaceHistory = []
        findHistory = []
        defaults = nil

        super.init(coder: coder)
    }

    public override var windowNibName: NSNib.Name? {
        return "Find"
    }

    deinit {
        // Stop receiving notifications
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Updating the history

    private final func addPhraseToFindHistory(_ phrase: String) {
        // Ensure that we don't store a duplicate copy of the phrase
        let lastIndex = (findHistory as NSArray).index(of: phrase)
        if lastIndex != NSNotFound {
            findHistory.remove(at: lastIndex)
        }

        // Insert the new phrase into the find history
        findHistory.insert(phrase, at: 0)

        // Ensure that we limit the number of items in the history
        while findHistory.count > FIND_HISTORY_LENGTH {
            findHistory.removeLast()
        }

        // Store in the user defaults
        defaults?.set(findHistory, forKey: IFFindHistoryPref)

        // Update the combo box
        findPhrase?.reloadData()
    }

    private final func addPhraseToReplaceHistory(_ phrase: String) {
        // Ensure that we don't store a duplicate copy of the phrase
        let lastIndex = (replaceHistory as NSArray).index(of: phrase)
        if lastIndex != NSNotFound {
            replaceHistory.remove(at: lastIndex)
        }

        // Insert the new phrase into the find history
        replaceHistory.insert(phrase, at: 0)

        // Ensure that we limit the number of items in the history
        while replaceHistory.count > FIND_HISTORY_LENGTH {
            replaceHistory.removeLast()
        }

        // Store in the user defaults
        defaults?.set(replaceHistory, forKey: IFReplaceHistoryPref)

        // Update the combo box
        replacePhrase?.reloadData()
    }

    // MARK: - Actions

    private final func currentFindType() -> IFFindType {
        let selected = searchType?.selectedItem

        var flags = IFFindType.invalidType.rawValue
        if ignoreCase?.state == .on { flags |= IFFindType.caseInsensitive.rawValue }

        if selected === containsItem {
            return IFFindType(rawValue: IFFindType.contains.rawValue | flags)!
        } else if selected === beginsWithItem {
            return IFFindType(rawValue: IFFindType.beginsWith.rawValue | flags)!
        } else if selected === completeWordItem {
            return IFFindType(rawValue: IFFindType.completeWord.rawValue | flags)!
        } else if selected === regexpItem {
            return IFFindType(rawValue: IFFindType.regexp.rawValue | flags)!
        } else {
            return IFFindType(rawValue: IFFindType.contains.rawValue | flags)!
        }
    }

    private final func setLastSearch(_ phrase: String) {
        if !(phrase as NSString).isEqual(lastSearch) {
            // Set the last search phrase
            lastSearch = phrase

            // Close the 'find all' results
            showAuxiliaryView(nil)
        }

        lastSearchType = searchType?.selectedItem
        lastSearchIgnoreCase = (ignoreCase?.state == .on)
    }

    @IBAction func findNext(_ sender: Any?) {
        if (findPhrase?.stringValue ?? "").isEmpty {
            return
        }

        if let activeDelegate, activeDelegate.responds(to: #selector(IFFindDelegate.findNextMatch(_:of:completionHandler:))) {
            // Close the 'all' dialog if necessary
            setLastSearch(findPhrase?.stringValue ?? "")

            // Get the delegate to perform the search
            activeDelegate.findNextMatch(findPhrase?.stringValue ?? "",
                                         of: currentFindType(),
                                         completionHandler: nil)

            // Record the phrase in the history
            addPhraseToFindHistory(findPhrase?.stringValue ?? "")
        }
    }

    @IBAction func findPrevious(_ sender: Any?) {
        if (findPhrase?.stringValue ?? "").isEmpty {
            return
        }

        if let activeDelegate, activeDelegate.responds(to: #selector(IFFindDelegate.findPreviousMatch(_:of:completionHandler:))) {
            // Close the 'all' dialog if necessary
            setLastSearch(findPhrase?.stringValue ?? "")

            // Get the delegate to perform the search
            activeDelegate.findPreviousMatch?(findPhrase?.stringValue ?? "",
                                              of: currentFindType(),
                                              completionHandler: nil)

            // Record the phrase in the history
            addPhraseToFindHistory(findPhrase?.stringValue ?? "")
        }
    }

    @IBAction func replaceAndFind(_ sender: Any?) {
        if (findPhrase?.stringValue ?? "").isEmpty {
            return
        }
        if let activeDelegate,
           activeDelegate.responds(to: #selector(IFFindDelegate.replaceFound(with:))),
           activeDelegate.responds(to: #selector(IFFindDelegate.findNextMatch(_:of:completionHandler:))) {

            let replaceString: String
            if (currentFindType().rawValue & 0xff) == IFFindType.regexp.rawValue {
                // The replace string has \1 \2 etc translated into actual string values using the last found regex groups
                replaceString = IFFindResult.string(byReplacingGroups: replacePhrase?.stringValue ?? "",
                                                    regexFoundGroups: activeDelegate.lastFoundGroups ?? nil)
            } else {
                replaceString = replacePhrase?.stringValue ?? ""
            }

            addPhraseToReplaceHistory(replacePhrase?.stringValue ?? "")
            activeDelegate.replaceFound?(with: replaceString)
            activeDelegate.findNextMatch(findPhrase?.stringValue ?? "",
                                         of: currentFindType(),
                                         completionHandler: nil)
        }
    }

    @IBAction func replace(_ sender: Any?) {
        if let activeDelegate, activeDelegate.responds(to: #selector(IFFindDelegate.replaceFound(with:))) {
            let replaceString: String
            if (currentFindType().rawValue & 0xff) == IFFindType.regexp.rawValue {
                // The replace string has \1 \2 etc translated into actual string values using the last found regex groups
                replaceString = IFFindResult.string(byReplacingGroups: replacePhrase?.stringValue ?? "",
                                                    regexFoundGroups: activeDelegate.lastFoundGroups ?? nil)
            } else {
                replaceString = replacePhrase?.stringValue ?? ""
            }

            addPhraseToReplaceHistory(replacePhrase?.stringValue ?? "")
            activeDelegate.replaceFound?(with: replaceString)
        }
    }

    @IBAction func useSelectionForFind(_ sender: Any?) {
        // Hack: ensure the window is loaded
        _ = window

        if let activeDelegate, activeDelegate.responds(to: #selector(IFFindDelegate.currentSelectionForFind(completionHandler:))) {
            activeDelegate.currentSelectionForFind?(completionHandler: { searchFor in
                if let searchFor, !searchFor.isEmpty {
                    self.findPhrase?.stringValue = searchFor
                    self.searchType?.select(self.containsItem)

                    self.findNext(self)
                    return
                } else {
                    NSSound.beep()
                }
            })
        }
    }

    @IBAction func findTypeChanged(_ sender: Any?) {
        if searchType?.selectedItem === regexpItem {
            showAuxiliaryView(regexpHelpView)
        } else {
            if auxView === regexpHelpView {
                showAuxiliaryView(nil)
            }
        }
    }

    // MARK: - Updating the find delegate

    private final func isSuitableDelegate(_ object: AnyObject?) -> Bool {
        guard let object else { return false }

        if object.responds(to: #selector(IFFindDelegate.findNextMatch(_:of:completionHandler:))) {
            return true
        } else {
            return false
        }
    }

    private final func chooseDelegate(from window: NSWindow?) -> IFFindDelegate? {
        // Default delegate behaviour is to look at the window controller first, then the window, then the views
        // up the chain from the active view
        // Like the Objective-C, this takes anything that finds the next match as a delegate, without asking if it
        // says it is one
        let controller = window?.windowController
        if let controller, isSuitableDelegate(controller) {
            return unsafeBitCast(controller, to: IFFindDelegate.self)
        } else if let window, isSuitableDelegate(window) {
            return unsafeBitCast(window, to: IFFindDelegate.self)
        }

        var responder = window?.firstResponder
        while let thisResponder = responder {
            if isSuitableDelegate(thisResponder) {
                return unsafeBitCast(thisResponder, to: IFFindDelegate.self)
            }
            responder = thisResponder.nextResponder
        }

        return nil
    }

    private final func canSearch() -> Bool {
        return activeDelegate?.responds(to: #selector(IFFindDelegate.findNextMatch(_:of:completionHandler:))) ?? false
    }

    private final func canReplace() -> Bool {
        return activeDelegate?.responds(to: #selector(IFFindDelegate.replaceFound(with:))) ?? false
    }

    private final func canFindAll() -> Bool {
        return activeDelegate?.responds(to: #selector(IFFindDelegate.findAllMatches(_:of:in:in:withIdentifier:))) ?? false
    }

    private final func canReplaceAll() -> Bool {
        return activeDelegate?.responds(to: #selector(IFFindDelegate.replaceFindAllResult(_:with:offset:))) ?? false
    }

    private final func supportsFindType(_ type: IFFindType) -> Bool {
        if let activeDelegate {
            if activeDelegate.responds(to: #selector(IFFindDelegate.canUse(_:))) {
                // If the delegate specifies what types of thing it can find, then use that
                return activeDelegate.canUse!(type)
            } else {
                // Default is to support all but regular expressions
                if type == .regexp { return false }
                return true
            }
        }

        // If there's no delegate, allow everything
        return true
    }

    private final func updateControls(_ copyLastState: Bool) {
        findPhrase?.isEnabled = canSearch() || canFindAll()
        replacePhrase?.isEnabled = canReplace()

        ignoreCase?.isEnabled = canSearch()
        searchType?.isEnabled = canSearch()

        containsItem?.isEnabled = supportsFindType(.contains)
        beginsWithItem?.isEnabled = supportsFindType(.beginsWith)
        completeWordItem?.isEnabled = supportsFindType(.completeWord)
        regexpItem?.isEnabled = supportsFindType(.regexp)

        let hasSearchTerm = !(findPhrase?.stringValue ?? "").isEmpty

        next?.isEnabled = canSearch() && hasSearchTerm
        previous?.isEnabled = canSearch() && hasSearchTerm
        replaceAndFind?.isEnabled = canReplace() && hasSearchTerm
        replace?.isEnabled = canReplace() && hasSearchTerm
        replaceAll?.isEnabled = canReplaceAll() && hasSearchTerm
        findAll?.isEnabled = canFindAll() && hasSearchTerm

        if copyLastState {
            // 'Contains' is the basic type of search
            if lastSearchType == nil || !(lastSearchType?.isEnabled ?? false) {
                searchType?.select(containsItem)
            }
            else {
                searchType?.select(lastSearchType)
            }

            ignoreCase?.state = lastSearchIgnoreCase ? .on : .off
        }
    }

    private final func setActiveDelegate(_ newDelegate: IFFindDelegate?) {
        if newDelegate === activeDelegate { return }

        activeDelegate = newDelegate

        findIdentifier = nil

        if auxView !== regexpHelpView {
            showAuxiliaryView(nil)
        }

        updateControls(false)
    }

    func updateFromFirstResponder() {
        let mainWindow = NSApp.mainWindow
        setActiveDelegate(chooseDelegate(from: mainWindow))
    }

    public override func windowDidLoad() {
        updateFromFirstResponder()
        updateControls(true)

        winFrame = window?.frame ?? .zero
        borders = (window?.frame.size.height ?? 0)
                + (findAllView?.frame.size.height ?? 0)
                - (findAllTable?.frame.size.height ?? 0)

        // When clicked, call the routine
        findAllTable?.action = #selector(onItemClicked)

        // Restore frame position
        window?.setFrameUsingName("FindFrame")
    }

    public override func showWindow(_ sender: Any?) {
        // Standard behaviour
        super.showWindow(sender)

        window?.collectionBehavior = [.moveToActiveSpace, .transient]

        // Set the first responder
        window?.makeFirstResponder(findPhrase)
    }

    // MARK: - 'Find all'
    private final func heightToFitResults() -> CGFloat {
        // Calculate new height of table based on the number of results we have.
        let rowHeight = (findAllTable?.rowHeight ?? 0) + (findAllTable?.intercellSpacing.height ?? 0)
        let newTableHeight = CGFloat(min(20, findAllResults.count)) * rowHeight

        // Hieght of window = height of everything else + height of table
        return borders + newTableHeight                 // Calculate new height of window
    }

    private final func resizeToFitResults() {
        let newHeight = heightToFitResults()                        // Calculate new window height required
        var windowFrame = window?.frame ?? .zero                    // Get current height of window
        let delta = newHeight - windowFrame.size.height             // Find out the difference
        windowFrame.origin.y -= delta                               // Adjust the window origin so the top-left of the window remains in the same place
        windowFrame.size.height = newHeight                         // Adjust to the new height
        window?.setFrame(windowFrame, display: true, animate: false) // Set the window frame
    }

    private final func updateFindAllResults() {
        // Show nothing if there are no results in the find view
        if findAllResults.count <= 0 {
            showAuxiliaryView(foundNothingView)
            return
        }

        // Refresh the table
        findAllTable?.reloadData()

        // Compose the results count message
        var message: String
        if findAllResults.count == 1 {
            message = IFUtility.localizedString("Found Result Count")
        } else {
            message = IFUtility.localizedString("Found Results Count")
            message = String(format: message, findAllResults.count)
        }
        findCountText?.stringValue = message

        // Show the find all view
        showAuxiliaryView(findAllView)

        // Resize window to fit the number of results
        resizeToFitResults()
    }

    @IBAction func findAll(_ sender: Any?) {
        if !canFindAll() {
            return
        }

        // Add the find phrase to the history
        lastSearch = findPhrase?.stringValue ?? ""
        addPhraseToFindHistory(findPhrase?.stringValue ?? "")

        // Load a new 'find all' view
        replaceAll?.isEnabled = canReplaceAll()

        // Create a new find identifier
        findAllCount += 1
        let identifier = NSNumber(value: findAllCount)
        findIdentifier = identifier

        // Clear out the find results
        findAllResults = []

        // Perform the initial find
        let findResults = activeDelegate?.findAllMatches?(findPhrase?.stringValue ?? "",
                                                          of: currentFindType(),
                                                          in: .currentPage,
                                                          in: self,
                                                          withIdentifier: identifier)
        if let findResults {
            findAllResults.append(contentsOf: findResults)
        }

        updateFindAllResults()
    }

    // MARK: - Performing 'replace all'

    @IBAction func replaceAll(_ sender: Any?) {
        if !canReplaceAll() {
            return
        }

        findAll(sender)

        // Store the replace phrase in the replacement history
        addPhraseToReplaceHistory(replacePhrase?.stringValue ?? "")

        // Indicate that a 'replace all' operation is starting
        activeDelegate?.beginReplaceAll?(self)

        // Get the replacement string
        let replacement = replacePhrase?.stringValue ?? ""

        // Replace each match in turn
        var offset: Int32 = 0
        for x in 0..<findAllResults.count {
            let thisResult = findAllResults[x]

            let actualReplacement: String

            if (currentFindType().rawValue & 0xff) == IFFindType.regexp.rawValue {
                // Insert the group values into the replacement string instead of \1 \2 \3 etc...
                actualReplacement = thisResult.string(byReplacingGroups: replacement)
            }
            else {
                actualReplacement = replacement
            }

            let newResult = activeDelegate?.replaceFindAllResult?(thisResult,
                                                                  with: actualReplacement,
                                                                  offset: &offset)
            if let newResult {
                findAllResults[x] = newResult
            } else {
                thisResult.setError(true)
            }
        }

        // Finished
        activeDelegate?.finishedReplaceAll?(self)

        // Update the table with the new results
        findAllTable?.reloadData()
        findAllTable?.needsDisplay = true
    }

    // MARK: - The auxiliary view

    private final func showAuxiliaryView(_ newAuxView: NSView?) {
        // Do nothing if the aux view hasn't changed
        if newAuxView === auxView { return }

        // Hide the old auxiliary view
        if let auxView {
            auxView.removeFromSuperview()
            self.auxView = nil
        }

        // Show the new auxiliary view
        var auxFrame = NSRect(x: 0, y: 0, width: 0, height: 0)

        if let newAuxView {
            // Remember this view
            auxFrame = newAuxView.frame

            // Set its size
            auxFrame.origin = NSPoint(x: 0, y: (auxViewPanel?.frame.size.height ?? 0) - auxFrame.size.height)
            auxFrame.size.width = window?.contentView?.frame.size.width ?? 0
            newAuxView.frame = auxFrame
        }

        // Resize the window
        var currentWinFrame = window?.frame ?? .zero

        let newWindowHeight = winFrame.size.height + auxFrame.size.height

        let heightDiff = newWindowHeight - currentWinFrame.size.height
        currentWinFrame.size.height += heightDiff
        currentWinFrame.origin.y -= heightDiff

        window?.setFrame(currentWinFrame, display: true)

        // Add the new view
        if let newAuxView {
            auxView = newAuxView

            auxFrame.origin = NSPoint(x: 0, y: (auxViewPanel?.frame.size.height ?? 0) - auxFrame.size.height)
            auxFrame.size.width = window?.contentView?.frame.size.width ?? 0
            newAuxView.frame = auxFrame

            newAuxView.removeFromSuperview()
            auxViewPanel?.addSubview(newAuxView)
        }
    }

    // MARK: - Combo box delegate methods

    @IBAction func comboBoxEnterKeyPress(_ sender: Any?) {
        if (sender as AnyObject?) === findPhrase {
            // Pressing return in the findPhrase combo box will close the find window.
            findNext(self)
            window?.orderOut(self)
        } else if (sender as AnyObject?) === replacePhrase {
            findNext(self)
        } else {
            findNext(self)
        }
    }
}

/// The data sources and delegates the nib connects, the table's action and the notifications, which the header doesn't declare
extension IFFindController {
    // MARK: - Updating the find delegate

    @objc(mainWindowChanged:)
    public func mainWindowChanged(_ not: Notification) {
        // Update this control from the first responder
        setActiveDelegate(chooseDelegate(from: not.object as? NSWindow))
    }

    // MARK: - The find all table

    @objc(numberOfRowsInTableView:)
    public func numberOfRows(in aTableView: NSTableView) -> Int {
        return findAllResults.count
    }

    @objc(tableView:objectValueForTableColumn:row:)
    public func tableView(_ aTableView: NSTableView,
                          objectValueFor aTableColumn: NSTableColumn?,
                          row rowIndex: Int) -> Any? {
        if rowIndex >= findAllResults.count {
            return nil
        }

        let row = findAllResults[rowIndex]
        return row.attributedContext
    }

    @objc(onItemClicked)
    public func onItemClicked() {
        let clickedRow = findAllTable?.clickedRow ?? -1

        if clickedRow >= 0 {
            if let activeDelegate, activeDelegate.responds(to: #selector(IFFindDelegate.highlight(_:))) {
                activeDelegate.highlight?(findAllResults[clickedRow])
            }
        }
    }

    @objc(tableViewSelectionDidChange:)
    public func tableViewSelectionDidChange(_ aNotification: Notification) {
        guard let findAllTable, findAllTable.numberOfSelectedRows == 1 else { return }

        let selectedRow = findAllTable.selectedRow
        if let activeDelegate, activeDelegate.responds(to: #selector(IFFindDelegate.highlight(_:))) {
            activeDelegate.highlight?(findAllResults[selectedRow])
        }
    }

    @objc(tableView:shouldShowCellExpansionForTableColumn:row:)
    public func tableView(_ tableView: NSTableView,
                          shouldShowCellExpansionFor tableColumn: NSTableColumn?,
                          row: Int) -> Bool {
        // Turn off expansion tooltips
        return false
    }

    // MARK: - Find/replace history

    @objc(comboBox:objectValueForItemAtIndex:)
    public func comboBox(_ aComboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        // Choose the history list that's being displayed in the specified combo box
        var itemArray: [Any]? = nil
        if aComboBox === findPhrase {
            itemArray = findHistory
        } else if aComboBox === replacePhrase {
            itemArray = replaceHistory
        }

        // Return the item
        guard let itemArray, index >= 0, index < itemArray.count else {
            return nil
        }
        return itemArray[index]
    }

    @objc(numberOfItemsInComboBox:)
    public func numberOfItems(in aComboBox: NSComboBox) -> Int {
        // Choose the history list that's being displayed in the specified combo box
        var itemArray: [Any]? = nil
        if aComboBox === findPhrase {
            itemArray = findHistory
        } else if aComboBox === replacePhrase {
            itemArray = replaceHistory
        }

        // Return the number of items
        guard let itemArray else {
            return 0
        }
        return itemArray.count
    }

    // MARK: - Combo box delegate methods

    @objc(controlTextDidChange:)
    public func controlTextDidChange(_ aNotification: Notification) {
        if (aNotification.object as AnyObject?) === findPhrase {
            updateControls(false)
        }
    }

    // MARK: - Window delegate methods

    @objc(windowWillClose:)
    public func windowWillClose(_ notification: Notification) {
        let win = notification.object as? NSWindow

        if win === window {
            // Clear the find all results
            findAllResults.removeAll()
            showAuxiliaryView(nil)
            window?.saveFrame(usingName: "FindFrame")
        }
    }
}
