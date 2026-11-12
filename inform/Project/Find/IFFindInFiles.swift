//
//  IFFindInFiles.swift
//  Inform
//
//  Created by Toby Nelson in 2014
//  Translated from Objective-C in November 2026. The interface is still IFFindInFiles.h.
//

import Cocoa

/// Runs `body` holding `lock`, as Objective-C's @synchronized does (the find window holds the results' lock that way)
private func synchronized<T>(_ lock: AnyObject, _ body: () throws -> T) rethrows -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    return try body()
}

/// A text or file to search, and where it is (handed to the search's thread, and not changed)
private final class IFSearchItem: Sendable {
    let text: String?
    let filepath: String?
    let location: IFFindLocation

    init(text textString: String?,
         filePath filepathString: String?,
         location locationType: IFFindLocation) {
        text     = textString
        filepath = filepathString
        location = locationType
    }
}

@objc @implementation
extension IFFindInFiles {
    /// The items a search is to search, gathered on the main thread as it starts
    private final var searchItems: [IFSearchItem] = []
    private final var foundResults: [IFFindResult] = []

    /// Counts the searches started. A search is left off once another is started, and its results and progress
    /// are then left out, so it's kept behind the results' lock.
    private final var searchNumber = 0
    let searchResultsLock = NSObject()

    /// Whether this is the latest search started
    private final func isLatestSearch(_ search: Int) -> Bool {
        return synchronized(searchResultsLock) {
            searchNumber == search
        }
    }

    private final func foundMatch(forSearch search: Int,
                                  inFile filename: String?,
                                  rangeInFile fileRange: NSRange,
                                  documentDisplayName: String?,
                                  documentSortName: String?,
                                  locationType: IFFindLocation,
                                  context: String,
                                  contextRange: NSRange,
                                  exampleName: String?,
                                  exampleAnchorTag: String?,
                                  codeAnchorTag: String?,
                                  definitionAnchorTag: String?,
                                  regexFoundGroups: [String]?) {
        let result = IFFindResult(filepath: filename,
                                  rangeInFile: fileRange,
                                  documentDisplayName: documentDisplayName,
                                  documentSortName: documentSortName,
                                  locationType: locationType,
                                  context: context,
                                  contextRange: contextRange,
                                  exampleName: exampleName,
                                  exampleAnchorTag: exampleAnchorTag,
                                  codeAnchorTag: codeAnchorTag,
                                  definitionAnchorTag: definitionAnchorTag,
                                  regexFoundGroups: regexFoundGroups)
        synchronized(searchResultsLock) {
            if searchNumber == search {
                foundResults.append(result)
            }
        }
    }

    class func getContextFromText(_ textString: String,
                                  withLocation location: UInt,
                                  andLength matchLength: UInt,
                                  findingContextRange rangeOut: UnsafeMutablePointer<NSRange>) -> String {
        let textString = textString as NSString
        let location = Int(location)
        let matchLength = Int(matchLength)

        //
        let set = CharacterSet(charactersIn: "\n\r")
        let startRange = textString.rangeOfCharacter(from: set,
                                                     options: .backwards,
                                                     range: NSRange(location: 0, length: location))
        let endRange = textString.rangeOfCharacter(from: set,
                                                   options: .literal,
                                                   range: NSRange(location: location + matchLength, length: textString.length - (location + matchLength)))
        var lowContext = (startRange.location == NSNotFound) ? 0 : startRange.location
        var highContext = (endRange.location == NSNotFound) ? textString.length - 1 : endRange.location

        // Skip past whitespace / newlines at either end, but not into the match, which may end with some
        let whiteSet = NSCharacterSet(charactersIn: "\n\r \t")
        while (lowContext < location) && whiteSet.characterIsMember(textString.character(at: lowContext)) {
            lowContext += 1
        }
        while (highContext > location) && (highContext >= location + matchLength) &&
              whiteSet.characterIsMember(textString.character(at: highContext)) {
            highContext -= 1
        }

        precondition(highContext < textString.length, "Bad context range (high)")
        precondition(lowContext <= highContext, "Bad context range (swapped)")

        rangeOut.pointee = NSRange(location: location - lowContext, length: matchLength)
        return textString.substring(with: NSRange(location: lowContext, length: highContext + 1 - lowContext))
    }

    private static func exampleInfoForRange(_ range: NSRange,
                                            in exampleInfo: [String: IFExampleInfo]?) -> IFExampleInfo? {
        if let exampleInfo {
            for (_, info) in exampleInfo {
                if (range.location >= info.range.location) &&
                   ((range.location + range.length) <= (info.range.location + info.range.length)) {
                    return info
                }
            }
        }
        return nil
    }

    private static func codeInfoForRange(_ range: NSRange, in codeInfo: [IFCodeInfo]?) -> IFCodeInfo? {
        if let codeInfo {
            for info in codeInfo {
                if (range.location >= info.range.location) &&
                   ((range.location + range.length) <= (info.range.location + info.range.length)) {
                    return info
                }
            }
        }
        return nil
    }

    private static func definitionInfoForRange(_ range: NSRange, in definitionInfo: [IFCodeInfo]?) -> IFCodeInfo? {
        if let definitionInfo {
            for info in definitionInfo {
                if (range.location >= info.range.location) &&
                   ((range.location + range.length) <= (info.range.location + info.range.length)) {
                    return info
                }
            }
        }
        return nil
    }

    private final func searchThread(forSearch search: Int,
                                    items: [IFSearchItem],
                                    withPhrase searchPhrase: String,
                                    searchType: IFFindType,
                                    locations searchLocations: IFFindLocation,
                                    progressBlock: @escaping @MainActor @Sendable (Int32, Int32, Int32) -> Void) {
        // memory pool
        autoreleasepool {
            do {
                let totalSearchItems = Int32(items.count)
                var progressCount: Int32 = 0
                var resultCount: Int32

                for searchItem in items {
                    // Leave off if another search has started
                    if !isLatestSearch(search) { return }

                    // Retrieve values from it
                    var storage                 = searchItem.text
                    let filename                = searchItem.filepath
                    let locationType            = searchItem.location

                    var displayName = filename.map { ($0 as NSString).lastPathComponent }.map { ($0 as NSString).deletingPathExtension }
                    var sortKey: String? = nil

                    var exampleInfo: [String: IFExampleInfo]? = nil
                    var codeInfo: [IFCodeInfo]? = nil
                    var definitionInfo: [IFCodeInfo]? = nil
                    var lastFoundInExample: String? = nil
                    var foundOutsideExample = false
                    var onlyOneMatchPerSegment = false          // I define a segment to be an Example or the text outside an Example.

                    if storage == nil, let filename {
                        // What we do depends on file type
                        var res: NSAttributedString? = nil
                        let extn = ((filename as NSString).pathExtension as NSString).lowercased

                        // .inf, .h, .ni, .i7, .i7x, .w (a literate extension's contents and sections), .txt and those with
                        // no extension are treated as text files
                        // .rtf or .rtfd are opened as RTF files
                        // .html or .htm are opened as HTML files
                        // all other file types are not searched
                        if extn == "" ||
                           extn == "h" ||
                           extn == "ni" ||
                           extn == "i7" ||
                           extn == "inf" ||
                           extn == "i7x" ||
                           extn == "w" ||
                           extn == "txt" {
                            let fileContents = try? String(contentsOfFile: filename,
                                                           encoding: String.Encoding(rawValue: IFProjectTypes.encoding(forFilename: filename)))
                            if let fileContents { res = NSAttributedString(string: fileContents) }
                        } else if extn == "rtf" ||
                                  extn == "rtfd" {
                            res = try? NSAttributedString(url: URL(fileURLWithPath: filename),
                                                          options: [:],
                                                          documentAttributes: nil)
                        } else if extn == "html" ||
                                  extn == "htm" {
                            // Parse the file
                            let fileData = NSData(contentsOfFile: filename)
                            let fileString = fileData.flatMap { String(data: $0 as Data, encoding: .utf8) }
                            // (A file that can't be read, or isn't UTF-8, is parsed as no text, as it was when
                            // Objective-C gave the parser nil)
                            let fileContents = IFDocParser(html: fileString ?? "")

                            // Work out the display name
                            let title = fileContents.attributes[.title] as? String
                            let section = fileContents.attributes[.section] as? String

                            // Retrieve the storage contents. A page of the documentation without a search title
                            // and section isn't searched: the contents pages have none.
                            if !locationType.contains(.documentationBasic) || (title != nil && section != nil) {
                                storage = fileContents.plainText
                            }

                            sortKey = fileContents.attributes[.sort] as? String

                            if let title, let section {
                                displayName = "\(section): \(title)"
                            } else {
                                displayName = fileContents.attributes[.htmlTitle] as? String
                            }

                            exampleInfo     = fileContents.exampleInfo
                            codeInfo        = fileContents.codeInfo
                            definitionInfo  = fileContents.definitionInfo

                            onlyOneMatchPerSegment = true
                        }

                        if let res {
                            storage = res.string
                        }
                    }

                    if sortKey == nil { sortKey = displayName }

                    // storage now contains the string for the file/internal data - search it
                    if let storage {
                        var searchPosition: UInt = 0
                        var matchRange: NSRange
                        var matchGroups: NSArray?

                        repeat {
                            matchRange = IFScanner.findNextMatch(searchPhrase,
                                                                 storage: storage,
                                                                 position: searchPosition,
                                                                 options: searchType,
                                                                 regexFoundGroups: &matchGroups)
                            if matchRange.location != NSNotFound {
                                var contextRange = NSRange()
                                let alreadyFound: Bool

                                //
                                // Found a match.
                                //

                                //
                                // For HTML documentation files, we record a maximum of one search result
                                // per page, plus one result per example. I call these regions 'segments'.
                                // The following code enforces this.
                                //

                                // Get information about where the match occured
                                let info   = IFFindInFiles.exampleInfoForRange(matchRange, in: exampleInfo)
                                let cdInfo = IFFindInFiles.codeInfoForRange(matchRange, in: codeInfo)
                                let dfInfo = IFFindInFiles.definitionInfoForRange(matchRange, in: definitionInfo)

                                // Check if we have already found a result in this segment... Matches in code and
                                // definitions are all listed, so they don't count.
                                let isInText = (cdInfo == nil) && (dfInfo == nil)
                                if let info {
                                    //
                                    // The match is inside an example
                                    //
                                    alreadyFound = (lastFoundInExample != nil) && (lastFoundInExample!.compare(info.name) == .orderedSame)
                                    if isInText { lastFoundInExample = info.name }
                                }
                                else {
                                    //
                                    // The match is outside any examples
                                    //
                                    alreadyFound = foundOutsideExample
                                    if isInText { foundOutsideExample = true }
                                }

                                // Should we ignore this match?

                                // Ignore if it's already found in this segment
                                var ignoreThisMatch = alreadyFound && onlyOneMatchPerSegment && (cdInfo == nil) && (dfInfo == nil)

                                if !ignoreThisMatch {

                                    // If we are currently looking in documentation...
                                    if searchItem.location.contains(.documentationBasic) {

                                        // Ignore this match if it's in code, but we are not looking for code
                                        let isInCode = (cdInfo != nil)
                                        if isInCode && !searchLocations.contains(.documentationSource) {
                                            ignoreThisMatch = true
                                        }

                                        // Ignore this match if it's in definitions, when we are not looking for definitions
                                        let isInDefinitions = (dfInfo != nil)
                                        if isInDefinitions && !searchLocations.contains(.documentationDefinitions) {
                                            ignoreThisMatch = true
                                        }

                                        // Ignore this match if it's in basic, when we are not looking for basic
                                        if !isInDefinitions && !isInCode && !searchLocations.contains(.documentationBasic) {
                                            ignoreThisMatch = true
                                        }
                                    }
                                }

                                if !ignoreThisMatch {
                                    //
                                    // Calculate the context (i.e. the text around the match to display in the results)
                                    //
                                    let context = IFFindInFiles.getContextFromText(storage,
                                                                                   withLocation: UInt(matchRange.location),
                                                                                   andLength: UInt(matchRange.length),
                                                                                   findingContextRange: &contextRange)

                                    //
                                    // Record the result
                                    //
                                    foundMatch(forSearch: search,
                                               inFile: filename,
                                               rangeInFile: matchRange,
                                               documentDisplayName: displayName,
                                               documentSortName: sortKey,
                                               locationType: locationType,
                                               context: context,
                                               contextRange: contextRange,
                                               exampleName: info?.name,
                                               exampleAnchorTag: info?.anchorTag,
                                               codeAnchorTag: cdInfo?.anchorTag,
                                               definitionAnchorTag: dfInfo?.anchorTag,
                                               regexFoundGroups: matchGroups as? [String])
                                }

                                searchPosition = UInt(matchRange.location + 1)
                            }
                        }
                        while matchRange.location != NSNotFound
                    }


                    // Update progress
                    resultCount = synchronized(searchResultsLock) {
                        Int32(foundResults.count)
                    }
                    progressCount += 1

                    // (The values now, as an Objective-C block took them. A search that's been left off doesn't
                    // report what it had queued.)
                    DispatchQueue.main.async { [progressCount, resultCount] in
                        if self.isLatestSearch(search) {
                            progressBlock(progressCount, totalSearchItems + 1, resultCount)
                        }
                    }
                }

                // Finished searching - send one final update to the main thread
                resultCount = synchronized(searchResultsLock) {
                    Int32(foundResults.count)
                }
                DispatchQueue.main.async { [resultCount] in
                    if self.isLatestSearch(search) {
                        progressBlock(totalSearchItems + 1, totalSearchItems + 1, resultCount)
                    }
                }
            }

            // clean up
        }
    }


    // Gather files to search through...

    private final func addSearchText(_ text: String?,
                                     withFilePath filepath: String?,
                                     withLocation location: IFFindLocation) {
        // NSLog(@"Found text file %@ (length %d) in location %d", filepath, [text length], (int) location);

        let item = IFSearchItem(text: text, filePath: filepath, location: location)
        searchItems.append(item)
    }

    private final func addSearchFile(_ filepath: String,
                                     withLocation location: IFFindLocation) {
        addSearchText(nil, withFilePath: filepath, withLocation: location)
    }

    private final func addDocumentation() {
        // Find the documents to search
        guard let resourcePath = (Bundle.main.path(forResource: "index", ofType: "html") as NSString?)?.deletingLastPathComponent else {
            return
        }

        // Find all .htm and .html documents from the resources
        guard let dirEnum = FileManager.default.enumerator(atPath: resourcePath) else {
            return
        }

        for case let path as String in dirEnum {
            let extn = (path as NSString).pathExtension
            let description = (((path as NSString).lastPathComponent as NSString).deletingPathExtension as NSString).lowercased

            // Must be an html file of the documentation the app shows: Writing with Inform (WI_), the Recipe Book
            // (RB_) and the examples (eg_).
            if extn == "html" ||
               extn == "htm" {
                if description.hasPrefix("wi_") ||
                   description.hasPrefix("rb_") ||
                   description.hasPrefix("eg_") {
                    addSearchFile((resourcePath as NSString).appendingPathComponent(path),
                                  withLocation: .documentationBasic)
                }
            }
        }
    }

    @MainActor private final func addExtensions(_ project: IFProject) {
        let manager = IFExtensionsManager.sharedNaturalInform

        for info in manager.availableExtensions(withCompilerVersion: project.settings.compilerVersion) {
            for file in info.sourceFiles {
                addSearchFile(file,
                              withLocation: .extensions)
            }
        }
    }

    @MainActor private final func addSourceFiles(_ project: IFProject) {
        // Find all text in the project source files
        let sourceFiles = project.sourceFiles ?? [:]

        for (filepath, file) in sourceFiles {
            // A copy, as it's searched on another thread, and could be edited meanwhile. (Bridging the text
            // storage's string to Swift copies it; the copy shares the text until it's next edited, so it's quick.)
            addSearchText(file.string,
                          withFilePath: filepath,
                          withLocation: .source)
        }
    }

    var resultsCount: Int32 {
        return synchronized(searchResultsLock) {
            Int32(foundResults.count)
        }
    }

    var results: [IFFindResult] {
        return synchronized(searchResultsLock) {
            let sortedArray = foundResults.sorted { first, second in
                // Sort by location type first
                if first.locationType != second.locationType {
                    return first.locationType.rawValue < second.locationType.rawValue
                }

                // Then sort by document name (none sorts with any, as Objective-C's message to nil gave the same)
                guard let firstName = first.documentSortName, let secondName = second.documentSortName else {
                    return false
                }
                return firstName.compare(secondName, options: .numeric) == .orderedAscending
            }
            return sortedArray
        }
    }

    // (Swift's name for it leaves out words of the selector, so the selector is given)
    @objc(startFindInFilesWithPhrase:withSearchType:fromProject:withLocations:withProgressBlock:)
    @MainActor func start(withPhrase searchPhrase: String,
               withSearch searchType: IFFindType,
               from project: IFProject,
               withLocations locations: IFFindLocation,
               withProgressBlock progressBlock: @escaping IFFindInFilesProgressBlock) {
        searchItems.removeAll()

        if locations.contains(.documentationBasic) ||
           locations.contains(.documentationSource) ||
           locations.contains(.documentationDefinitions) {
            addDocumentation()
        }
        if locations.contains(.extensions) {
            addExtensions(project)
        }
        if locations.contains(.source) {
            addSourceFiles(project)
        }

        let items = searchItems
        searchItems.removeAll()

        // A search already running isn't waited for: it leaves off when it sees this one has started
        let search = synchronized(searchResultsLock) {
            searchNumber += 1
            foundResults.removeAll()
            return searchNumber
        }

        // Start a thread to do the search... GCD style
        let queue = DispatchQueue.global(qos: .default)
        queue.async {
            self.searchThread(forSearch: search,
                              items: items,
                              withPhrase: searchPhrase,
                              searchType: searchType,
                              locations: locations,
                              progressBlock: progressBlock)
        }
    }
}

// The search runs on another thread, with its own items, but its results and the latest search's number are kept
// behind a lock
extension IFFindInFiles: @unchecked Sendable {}
