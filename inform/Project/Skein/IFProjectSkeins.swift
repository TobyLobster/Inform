//
//  IFProjectSkeins.swift
//  Inform
//
//  Moved out of IFProject in November 2026. The interface is IFProjectSkeins.h.
//

import Foundation

@objc @implementation extension IFProjectSkeins {

    private final weak var project: IFProject?

    private final var _currentSkein: IFSkein?
    let skeins: NSMutableArray

    init(project: IFProject?) {
        self.project    = project
        skeins          = NSMutableArray()
        _currentSkein   = IFSkein(project: project)

        super.init()
    }

    private final func setSkeinTestCaseTitles() {
        if skeins.count > 0 {
            var index = 0
            for case let skein as IFSkein in skeins {
                if let testCases = project?.testCases, testCases.count > index {
                    skein.rootItem.command = testCases[index]["testTitle"] as? String
                }
                index += 1
            }
        }
    }

    var currentSkein: IFSkein? {
        return _currentSkein
    }

    func selectSkein(_ index: Int32) {
        if index < 0 {
            // Clear skein undos when setting no skein too, as undo mustn't change a skein that isn't shown
            if let currentSkein = _currentSkein { project?.undoManager?.removeAllActions(withTarget: currentSkein) }

            _currentSkein = nil
            let userDictionary: [AnyHashable: Any] = [:]
            NotificationCenter.default.post(name: .IFSkeinReplaced,
                                            object: project,
                                            userInfo: userDictionary)
            return
        }

        // Make sure we have enough skeins
        while skeins.count <= Int(index) {
            skeins.add(IFSkein(project: project))
        }

        // Has skein changed?
        let skein = skeins[Int(index)] as! IFSkein
        if _currentSkein !== skein {
            // Clear skein undos when setting skein
            if let currentSkein = _currentSkein { project?.undoManager?.removeAllActions(withTarget: currentSkein) }

            // Select the appropriate skein
            _currentSkein = skein

            // Set the titles of each skein to the titles of each test case
            setSkeinTestCaseTitles()

            // Let the skein views update based on the new skein
            let userDictionary: [AnyHashable: Any] = [:]
            NotificationCenter.default.post(name: .IFSkeinReplaced,
                                            object: project,
                                            userInfo: userDictionary)
        }

        // Make sure the skein updates
        _currentSkein?.postChanged(withAnimate: false,
                                   keepActiveVisible: false)
    }

    @objc(loadSkeinsFromProjectFile:isExtensionProject:)
    func loadSkeins(from projectFile: IFProjectFile?, isExtensionProject: Bool) {
        // Clear undo stack
        if let currentSkein = _currentSkein { project?.undoManager?.removeAllActions(withTarget: currentSkein) }

        // Disable undo
        project?.undoManager?.disableUndoRegistration()

        // Load skeins, in place of any read before, as by Revert To Saved
        skeins.removeAllObjects()
        if let project {
            projectFile?.load(into: skeins,
                              project: project,
                              isExtensionProject: isExtensionProject)
        }

        // Enable undo
        project?.undoManager?.enableUndoRegistration()

        // Select the first skein
        if isExtensionProject {
            selectSkein(-1)
        }
        else {
            selectSkein(0)
        }
    }

    // MARK: - Importing skein information

    func skein(fromRecording path: String) -> IFSkein? {
        let lineFeed: unichar       = 0x0A
        let carriageReturn: unichar = 0x0D

        // Read the file
        guard let fileData = NSData(contentsOfFile: path),
              let fileString = NSString(data: fileData as Data,
                                        encoding: String.Encoding.utf8.rawValue) else {
            return nil
        }

        // Pull out the lines from the file
        var lineStart = 0
        var pos = 0
        let len = fileString.length

        // Maximum length of 500k characters
        if len > 500000 { return nil }

        var lines: [String] = []

        while pos < len {
            // Get the next character
            let lineChar = fileString.character(at: pos)

            // Check for a newline
            if lineChar == lineFeed || lineChar == carriageReturn {
                // Maximum line length of 50 characters
                if pos - lineStart > 50 { return nil }

                // Maximum 10,000 moves
                if lines.count >= 10000 { return nil }

                // Get the current line
                let thisLine = fileString.substring(with: NSRange(location: lineStart, length: pos - lineStart))
                lines.append(thisLine)

                // Deal with <CR><LF> and <LF><CR> sequences
                if pos + 1 < len {
                    if lineChar == carriageReturn && fileString.character(at: pos + 1) == lineFeed { pos += 1 }
                    else if lineChar == lineFeed && fileString.character(at: pos + 1) == carriageReturn { pos += 1 }
                }

                // Store the start of the next line
                lineStart = pos + 1
            }
            pos += 1
        }

        // The last line needn't end with a newline
        if lineStart < len {
            if len - lineStart > 50 { return nil }
            if lines.count >= 10000 { return nil }

            lines.append(fileString.substring(with: NSRange(location: lineStart, length: len - lineStart)))
        }

        // Must be at least one line in the file
        if lines.count < 1 { return nil }

        // Build the new skein
        let newSkein = IFSkein(project: project)

        newSkein.activeItem = newSkein.rootItem

        for line in lines {
            newSkein.inputCommand(line)
        }

        return newSkein
    }

    @objc(importIntoCurrentSkeinFromFile:)
    func importIntoCurrentSkein(fromFile path: String) -> String? {
        // We can currently import .rec files, .txt files, zoomSave packages and .skein files
        // In the case of .rec/.txt files, they must be <300k, be valid UTF-8 and have less than 10000 lines
        // of a length no more than 50 characters each. (Anything else probably isn't a recording)
        let extn = (path as NSString).pathExtension.lowercased()

        var loadedSkein: IFSkein? = nil
        var loadError: String? = nil

        if extn == "txt" || extn == "rec" {
            loadedSkein = skein(fromRecording: path)

            loadError = IFUtility.localizedString("Recording Skein Load Failure", default: nil)
        } else if extn == "skein" {
            let skein = IFSkein(project: project)

            let parsed = (NSData(contentsOfFile: path) as Data?).map { skein.parseXmlData($0) } ?? false
            loadedSkein = parsed ? skein : nil
        } else if extn == "zoomsave" {
            let skein = IFSkein(project: project)

            let skeinPath = (path as NSString).appendingPathComponent("Skein.skein")
            let parsed = (NSData(contentsOfFile: skeinPath) as Data?).map { skein.parseXmlData($0) } ?? false
            loadedSkein = parsed ? skein : nil
        }

        if let loadedSkein {
            // Merge the new skein into the current skein
            while loadedSkein.rootItem.children.count > 0 {
                let child = loadedSkein.rootItem.children[0]
                child.removeFromParent()

                _currentSkein?.rootItem.addChild(child)
            }

            _currentSkein?.postChanged(withAnimate: false,
                                       keepActiveVisible: false)
            return nil
        }

        if loadError == nil {
            loadError = IFUtility.localizedString("Skein Load Failure", default: nil)
        }
        return loadError
    }
}
