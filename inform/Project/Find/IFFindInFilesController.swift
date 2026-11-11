//
//  IFFindInFilesController.swift
//  Inform
//
//  Created by Toby Nelson in 2014.
//  Translated from Objective-C in November 2026. The interface is still IFFindInFilesController.h.
//

import Cocoa

private let IFFindHistoryPref = "IFFindHistory"

private let FIND_HISTORY_LENGTH = 30

/// The shared find window controller
@MainActor private var sharedController: IFFindInFilesController?

/// Runs `body` holding `lock`, as Objective-C's @synchronized does (the search holds the results' lock that way)
private func synchronized<T>(_ lock: AnyObject, _ body: () throws -> T) rethrows -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    return try body()
}

@objc @implementation extension IFFindInFilesController {
    // The components of the find dialog
    @IBOutlet private final var findPhrase: NSComboBox?                         // The phrase to search for

    // Ignore case radio button
    @IBOutlet private final var ignoreCase: NSButton?                           // The 'ignore case' checkbox

    // Where to search
    @IBOutlet private final var findInSource: NSButton?                         // The 'Source' checkbox
    @IBOutlet private final var findInExtensions: NSButton?                     // The 'Extensions' checkbox
    @IBOutlet private final var findInDocumentationBasic: NSButton?             // The 'Documentation Basic' checkbox
    @IBOutlet private final var findInDocumentationSource: NSButton?            // The 'Documentation Source' checkbox
    @IBOutlet private final var findInDocumentationDefinitions: NSButton?       // The 'Documentation Definitions' checkbox

    // Pull down menu of how to search
    @IBOutlet private final var searchType: NSPopUpButton?                      // The 'contains/begins with/complete word/regexp' pop-up button
    @IBOutlet private final var containsItem: NSMenuItem?                       // Choices for the type of object to find
    @IBOutlet private final var beginsWithItem: NSMenuItem?
    @IBOutlet private final var completeWordItem: NSMenuItem?
    @IBOutlet private final var regexpItem: NSMenuItem?

    // Buttons
    @IBOutlet private final var findAll: NSButton?

    // Progress
    @IBOutlet private final var findProgress: NSProgressIndicator?              // The 'searching' progress indicator

    // Parent view to position extra content
    @IBOutlet private final var auxViewPanel: NSView?                           // The auxilary view panel
    @IBOutlet private final var findInFilesWindow: NSWindow?

    // The regular expression help view
    @IBOutlet private final var regexpHelpView: NSView?                         // The view containing information about regexps

    // The 'find all' views
    @IBOutlet private final var foundNothingView: NSView?                       // The view to show if we don't find any matches
    @IBOutlet private final var findAllView: NSView?                            // The main 'find all' view
    @IBOutlet private final var findAllTable: NSTableView?                      // The 'find all' results table
    @IBOutlet private final var findCountText: NSTextField?                     // The text count of how many results we have found

    // Things we've searched for
    private final var findHistory: [Any]                                        // The 'find' history
    private final var defaults: UserDefaults?                                   // Where the find history is kept

    private final var findAllResults: [IFFindResult] = []                       // The 'find all' results view
    private final var borders: CGFloat = 0

    // Auxiliary views
    private final var auxView: NSView?                                          // The auxiliary view that is being displayed
    private final var winFrame = NSRect.zero                                    // The default window frame

    // Project we are going to search
    private final var project: IFProject?                                       // Project to search in
    private final var controller: IFProjectController?                          // Project controller to use
    private final var findInFiles: IFFindInFiles                                // Object used to perform searching

    // MARK: - Initialisation

    @objc(sharedFindInFilesController) class func shared() -> IFFindInFilesController {
        if let sharedController {
            return sharedController
        }
        let controller = IFFindInFilesController(defaults: UserDefaults.standard)
        sharedController = controller
        return controller
    }

    init(defaults theDefaults: UserDefaults) {
        defaults = theDefaults

        // Get the find history
        findHistory = theDefaults.object(forKey: IFFindHistoryPref) as? [Any] ?? []

        findInFiles = IFFindInFiles()

        // The nib is named by windowNibName, as a Swift initialiser can't call initWithWindowNibName:
        super.init(window: nil)

        // Get notified when the window is closing...
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowWillClose(_:)),
                                               name: NSWindow.willCloseNotification,
                                               object: nil)
    }

    // Swift needs this, as NSWindowController's is required. The Objective-C inherited it, starting with nothing set.
    public required init?(coder: NSCoder) {
        findHistory = []
        defaults = nil
        findInFiles = IFFindInFiles()

        super.init(coder: coder)
    }

    public override var windowNibName: NSNib.Name? {
        return "FindInFiles"
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

    private final func currentFindLocation() -> IFFindLocation {
        var locations: IFFindLocation = []      // Nowhere
        if findInSource?.state == .on                   { locations.insert(.source) }
        if findInExtensions?.state == .on               { locations.insert(.extensions) }
        if findInDocumentationBasic?.state == .on       { locations.insert(.documentationBasic) }
        if findInDocumentationSource?.state == .on      { locations.insert(.documentationSource) }
        if findInDocumentationDefinitions?.state == .on { locations.insert(.documentationDefinitions) }
        return locations
    }

    private final func locationName(from findResult: IFFindResult) -> String {
        let locationTypeKey: String

        switch findResult.locationType {
        case .currentPage:
            locationTypeKey = "LocationCurrentPage"
        case .source:
            locationTypeKey = "LocationSource"
        case .extensions:
            locationTypeKey = "LocationExtensions"
        case .documentationSource, .documentationDefinitions, .documentationBasic:
            if findResult.recipeBookResult {
                locationTypeKey = "LocationDocumentationRecipeBook"
            }
            else {
                locationTypeKey = "LocationDocumentationWritingWithInform"
            }
        default:
            preconditionFailure("Could not find location name for location \(findResult.locationType.rawValue)")
        }

        return IFUtility.localizedString(locationTypeKey)
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

    private final func updateControls() {
        let hasSearchTerm = !(findPhrase?.stringValue ?? "").isEmpty

        // Enable or disable the buttons
        findAll?.isEnabled = hasSearchTerm

        // 'Contains' is the basic type of search
        if !(searchType?.selectedItem?.isEnabled ?? false) {
            searchType?.select(containsItem)
        }
    }

    public override func windowDidLoad() {
        updateControls()

        // Restore frame position
        window?.setFrameUsingName("FindInFilesFrame")

        winFrame = window?.frame ?? .zero
        borders = (window?.frame.size.height ?? 0)
                + (findAllView?.frame.size.height ?? 0)
                - (findAllTable?.frame.size.height ?? 0)

        findProgress?.isHidden = true
    }

    public override func showWindow(_ sender: Any?) {
        // Standard behaviour
        super.showWindow(sender)

        // Set the first responder
        window?.makeFirstResponder(findPhrase)
    }

    private final func resizeToFitResults() {
        // Calculate new height of table based on the number of results we have.
        let rowHeight = (findAllTable?.rowHeight ?? 0) + (findAllTable?.intercellSpacing.height ?? 0)
        let newTableHeight = CGFloat(min(20, findAllResults.count)) * rowHeight

        var windowFrame = window?.frame ?? .zero                    // Get current height of window
        let newHeight = borders + newTableHeight                    // Calculate new height of window
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

        // Disable displaying stuff on screen while we adjust window/view size and positions
        //NSDisableScreenUpdates();

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

        // Enable displaying stuff on screen now that we have adjusted window/view size and positions
        //NSEnableScreenUpdates();
    }

    func setProject(_ aProject: IFProject) {
        project = aProject
    }

    func setController(_ aController: IFProjectController) {
        controller = aController
    }

    func showFind(inFilesWindow aController: IFProjectController) {
        project = aController.document as? IFProject
        setController(aController)
        showWindow(self)
    }

    @objc(startFindInFilesSearchWithPhrase:withLocationType:withType:)
    func startFindInFilesSearch(withPhrase aPhrase: String,
                                withLocationType aLocationType: IFFindLocation,
                                with aType: IFFindType) {
        findPhrase?.stringValue = aPhrase

        // Set options
        ignoreCase?.state = (aType.rawValue & IFFindType.caseInsensitive.rawValue) != 0 ? .on : .off
        switch IFFindType(rawValue: aType.rawValue & ~IFFindType.caseInsensitive.rawValue)! {
        case .contains:     searchType?.select(containsItem)
        case .beginsWith:   searchType?.select(beginsWithItem)
        case .completeWord: searchType?.select(completeWordItem)
        case .regexp:       searchType?.select(regexpItem)
        default:            searchType?.select(containsItem)
        }

        findInSource?.state = aLocationType.contains(.source)                                       ? .on : .off
        findInExtensions?.state = aLocationType.contains(.extensions)                               ? .on : .off
        findInDocumentationBasic?.state = aLocationType.contains(.documentationBasic)               ? .on : .off
        findInDocumentationSource?.state = aLocationType.contains(.documentationSource)             ? .on : .off
        findInDocumentationDefinitions?.state = aLocationType.contains(.documentationDefinitions)   ? .on : .off

        findTypeChanged(self)
        updateControls()

        // Start the find in files
        findAll(self)
    }

    @IBAction func findAll(_ sender: Any?) {
        guard let project else {
            return
        }

        // Add the find phrase to the history
        addPhraseToFindHistory(findPhrase?.stringValue ?? "")

        // Clear out the find results
        findAllResults = []
        findAllTable?.reloadData()

        // Show progress
        findProgress?.isHidden = false
        findProgress?.isDisplayedWhenStopped = false
        findProgress?.minValue = 0.0
        findProgress?.maxValue = 1.0
        findProgress?.startAnimation(sender)

        // Start the find
        let locations = currentFindLocation()

        findInFiles.start(withPhrase: findPhrase?.stringValue ?? "",
                          withSearch: currentFindType(),
                          from: project,
                          withLocations: locations) { num, total, found in
            // Update progress
            let progress = CGFloat(num) / CGFloat(total)
            self.findProgress?.doubleValue = progress

            synchronized(self.findInFiles.searchResultsLock) {
                // Update results
                if Int(self.findInFiles.resultsCount) != self.findAllResults.count {
                    let results = self.findInFiles.results
                    self.findAllResults = results
                    self.updateFindAllResults()
                }

                // Have we finished?
                if num == total {
                    // Stop the progress indicator
                    self.findProgress?.stopAnimation(self)
                    self.findProgress?.isHidden = true

                    // Update the results.
                    self.updateFindAllResults()
                }
            }
        }
    }

    // MARK: - The find all table

    func tableView(_ tableView: NSTableView, didClickRow rowIndex: Int) {
        let row = findAllResults[rowIndex]

        var anchorTag = ""
        if let tag = row.definitionAnchorTag, !tag.isEmpty {
            anchorTag = tag
        } else if let tag = row.codeAnchorTag, !tag.isEmpty {
            anchorTag = tag
        } else if let tag = row.exampleAnchorTag, !tag.isEmpty {
            anchorTag = tag
        }

        //NSLog(@"tag is %@", anchorTag);
        controller?.searchShowSelectedItem(atLocation: row.fileRange.location,
                                           phrase: row.phrase,
                                           inFile: row.filepath ?? "",
                                           type: row.locationType,
                                           anchorTag: anchorTag)
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

        // Hack: Core animation is rubbish and screws everything up if you try to resize the window immediately after adding a layer to a view
        window?.displayIfNeeded()

        // Show the new auxiliary view
        var auxFrame = NSRect(x: 0, y: 0, width: 0, height: 0)

        if let newAuxView {
            // Remember this view
            auxFrame = newAuxView.frame

            // Set its size
            auxFrame.origin = NSPoint(x: 0, y: (auxViewPanel?.bounds.maxY ?? 0) - auxFrame.size.height)
            auxFrame.size.width = window?.contentView?.frame.size.width ?? 0
            newAuxView.frame = auxFrame
        }

        // Resize the window
        var newWinFrame = window?.frame ?? .zero

        let heightDiff = (winFrame.size.height + auxFrame.size.height) - newWinFrame.size.height
        newWinFrame.size.height += heightDiff
        newWinFrame.origin.y -= heightDiff

        window?.setFrame(newWinFrame, display: true)

        // Add the new view
        if let newAuxView {
            auxView = newAuxView

            auxFrame.origin = NSPoint(x: 0, y: (auxViewPanel?.bounds.maxY ?? 0) - auxFrame.size.height)
            auxFrame.size.width = window?.contentView?.frame.size.width ?? 0
            newAuxView.frame = auxFrame

            newAuxView.removeFromSuperview()
            auxViewPanel?.addSubview(newAuxView)
        }
    }

    // MARK: - Combo box delegate methods

    @IBAction func comboBoxEnterKeyPress(_ sender: Any?) {
        // Return in an empty find box does nothing, as Find All is disabled then
        if (sender as AnyObject?) === findPhrase && !(findPhrase?.stringValue ?? "").isEmpty {
            findAll(self)
        }
    }
}

/// Clicks on the results
extension IFFindInFilesController: IFFindClickableTableViewDelegate {
}

/// The data sources and delegate the nib connects, and the notifications, which the header doesn't declare
extension IFFindInFilesController {
    // MARK: - The find all table

    @objc(numberOfRowsInTableView:)
    public func numberOfRows(in aTableView: NSTableView) -> Int {
        return findAllResults.count
    }

    @objc(tableView:objectValueForTableColumn:row:)
    public func tableView(_ aTableView: NSTableView,
                          objectValueFor aTableColumn: NSTableColumn?,
                          row rowIndex: Int) -> Any? {
        precondition(rowIndex < findAllResults.count, "Table display error")
        if rowIndex >= findAllResults.count {
            return nil
        }
        let ident = aTableColumn?.identifier.rawValue
        let row = findAllResults[rowIndex]

        if ident == "location" {
            return locationName(from: row)
        } else if ident == "context" {
            return row.attributedContext
        }

        var document = row.documentDisplayName
        if document?.compare("story", options: .caseInsensitive) == .orderedSame {
            document = IFUtility.localizedString("Find Results Source Document",
                                                 default: "(Source Text)")
        }
        return document
    }

    @objc(tableView:shouldShowCellExpansionForTableColumn:row:)
    public func tableView(_ tableView: NSTableView,
                          shouldShowCellExpansionFor tableColumn: NSTableColumn?,
                          row: Int) -> Bool {
        // Turn off expansion tooltips
        return false
    }

    @objc(tableView:willDisplayCell:forTableColumn:row:)
    public func tableView(_ tableView: NSTableView,
                          willDisplayCell cell: Any,
                          for tableColumn: NSTableColumn?,
                          row rowIndex: Int) {
        precondition(rowIndex < findAllResults.count, "Table display error")
        if rowIndex >= findAllResults.count {
            return
        }

        let row = findAllResults[rowIndex]
        let cell = cell as? NSTextFieldCell
        if row.recipeBookResult {
            cell?.drawsBackground = true
            let result = (rowIndex & 1) != 0 ? NSColor(calibratedRed: 1.0, green: 1.0, blue: 210.0 / 255.0, alpha: 1.0) :
                                               NSColor(calibratedRed: 1.0, green: 1.0, blue: 224.0 / 255.0, alpha: 1.0)
            cell?.backgroundColor = result
        }
        else {
            cell?.drawsBackground = false
        }
    }

    // MARK: - Find history

    @objc(comboBox:objectValueForItemAtIndex:)
    public func comboBox(_ aComboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        // Choose the history list that's being displayed in the specified combo box
        var itemArray: [Any]? = nil
        if aComboBox === findPhrase {
            itemArray = findHistory
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
            updateControls()
        }
    }

    // MARK: - Window delegate methods
    @objc(windowWillClose:)
    public func windowWillClose(_ notification: Notification) {
        let win = notification.object as? NSWindow

        if win === findInFilesWindow {
            // Clear the find all results
            findAllResults = []
            showAuxiliaryView(nil)
            win?.saveFrame(usingName: "FindInFilesFrame")
        }
    }
}
