//
//  IFSourceTexts.swift
//  Inform
//
//  Moved out of IFProject in November 2026. The interface is IFSourceTexts.h.
//

import Cocoa

@objc @implementation extension IFSourceTexts {

    private final var _sourceFiles: [String: NSTextStorage]?

    /// The texts read from the disk, for files not in the Source folder itself, to be unregistered with the rest
    private final var otherTexts: [NSTextStorage]

    override init() {
        _sourceFiles = nil
        otherTexts = []

        super.init()
    }

    var texts: [String: NSTextStorage]? {
        return _sourceFiles
    }

    func unregisterTexts() {
        for (_, storage) in _sourceFiles ?? [:] {
            IFSyntaxManager.unregisterTextStorage(storage)
        }

        // The texts read from the disk are let go too, as nothing else would unregister them
        for storage in otherTexts {
            IFSyntaxManager.unregisterTextStorage(storage)
        }
        otherTexts = []
    }

    // == storage ==
    private final func storage(withString string: String,
                               forFilename filename: String,
                               undoManager: UndoManager?) -> NSTextStorage {
        var string = string.replacingOccurrences(of: "\r\n", with: "\n")
        string = string.replacingOccurrences(of: "\r", with: "\n")

        // Create the syntax-highlighting text storage object
        let res = NSTextStorage(string: string)

        IFSyntaxManager.register(res,
                                 filename: (filename as NSString).lastPathComponent,
                                 intelligence: IFProjectTypes.intelligence(forFilename: filename),
                                 undoManager: undoManager)
        return res
    }

    private final func storage(withAttributedString string: NSAttributedString?,
                               forFilename filename: String,
                               undoManager: UndoManager?) -> NSTextStorage {
        let res = NSTextStorage(attributedString: string ?? NSAttributedString())

        IFSyntaxManager.register(res,
                                 filename: (filename as NSString).lastPathComponent,
                                 intelligence: IFProjectTypes.intelligence(forFilename: filename),
                                 undoManager: undoManager)
        return res
    }

    private static func alternateStringEncoding(for encoding: UInt) -> UInt {
        if encoding == String.Encoding.utf8.rawValue {
            return String.Encoding.isoLatin1.rawValue
        }
        return String.Encoding.utf8.rawValue
    }

    private final func storage(withData fileContents: Data?,
                               forFilename filename: String,
                               undoManager: UndoManager?) -> NSTextStorage {
        let ext = (filename as NSString).pathExtension.lowercased()
        let loadAsRtf = ext == "rtf" ||
                        ext == "rtfd"

        if loadAsRtf {
            return storage(withAttributedString: NSAttributedString(rtf: fileContents ?? Data(),
                                                                    documentAttributes: nil),
                           forFilename: filename,
                           undoManager: undoManager)
        } else {
            let encoding = IFProjectTypes.encoding(forFilename: filename)

            // First, try loading with the default encoding
            var fileString = NSString(data: fileContents ?? Data(), encoding: encoding) as String?
            if fileString == nil {
                // Try to load with an alternative encoding...
                let newEncoding = IFSourceTexts.alternateStringEncoding(for: encoding)

                NSLog("Warning: file '%@' cannot be interpreted as string encoding %d: trying %d",
                      filename, Int32(truncatingIfNeeded: encoding), Int32(truncatingIfNeeded: newEncoding))

                fileString = NSString(data: fileContents ?? Data(), encoding: newEncoding) as String?
                if fileString == nil {
                    // We can't interpret this file in any way - report the failure.
                    NSLog("Warning: no text available for file '%@'", filename)
                    fileString = ""
                }
            }

            return storage(withString: fileString ?? "",
                           forFilename: filename,
                           undoManager: undoManager)
        }
    }

    // MARK: - Reading and writing

    @objc(readSourceDirectory:undoManager:)
    func read(sourceDirectory sourceDir: FileWrapper, undoManager: UndoManager?) {
        // The pages show the text storages a project read before, as by Revert To Saved, so they're kept
        let oldSourceFiles = _sourceFiles ?? [:]
        _sourceFiles = [:]
        let source = sourceDir.fileWrappers ?? [:]

        // Load all the source files
        for (key, wrapper) in source {
            if !wrapper.isRegularFile {
                continue
            }

            let regularFileContents = wrapper.regularFileContents

            let text = storage(withData: regularFileContents,
                               forFilename: key,
                               undoManager: undoManager)

            if let oldText = oldSourceFiles[key] {
                // A file read before is given its new text
                IFSyntaxManager.unregisterTextStorage(text)
                oldText.replaceCharacters(in: NSRange(location: 0, length: oldText.length), with: text)
                _sourceFiles?[key] = oldText
            } else {
                _sourceFiles?[key] = text
            }
        }

        // Remove the text of files that are gone
        for (key, oldText) in oldSourceFiles where _sourceFiles?[key] !== oldText {
            IFSyntaxManager.unregisterTextStorage(oldText)
        }
    }

    private final func dataForSourceFile(withKey key: String) -> Data? {
        // Get data
        let ext = (key as NSString).pathExtension.lowercased()

        if ext == "rtf" ||
           ext == "rtfd" {
            guard let str = _sourceFiles?[key] else {
                return nil
            }
            return str.rtf(from: NSRange(location: 0, length: str.length),
                           documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        } else {
            return _sourceFiles?[key]?.string.data(using: .utf8)
        }
    }

    @objc(writeIntoSourceDirectory:)
    func write(into sourceFileWrapper: FileWrapper?) {
        // Output all the source files to the project file wrapper
        for key in (_sourceFiles ?? [:]).keys {
            let data = dataForSourceFile(withKey: key)

            // Add FileWrapper to list
            if let oldWrapper = sourceFileWrapper?.fileWrappers?[key] {
                sourceFileWrapper?.removeFileWrapper(oldWrapper)
            }
            sourceFileWrapper?.addRegularFile(withContents: data ?? Data(), preferredFilename: key)
        }
    }

    // MARK: - A file's text

    @objc(textForFile:inProject:undoManager:)
    func text(forFile sourceFile: String?, inProjectAt projectURL: URL?, undoManager: UndoManager?) -> NSTextStorage? {
        // No file has no text (as for a project without a story file)
        guard var sourceFile else { return nil }

        let originalSourceFile  = sourceFile
        let sourceDir           = projectURL?.appendingPathComponent("Source").path

        // Refuse to return storage for files outside the project directory
        if let sourceDir, (sourceFile as NSString).isAbsolutePath {
            if !(sourceFile as NSString).standardizingPath.hasPrefix(sourceDir) {
                return nil
            }
        }

        if !(sourceFile as NSString).isAbsolutePath {
            // A project with no folder has no files
            guard let sourceDir, let projectDir = projectURL?.path else {
                return nil
            }

            // Force absolute path
            sourceFile = (sourceDir as NSString).appendingPathComponent(sourceFile)
            sourceFile = (sourceFile as NSString).standardizingPath

            if !FileManager.default.fileExists(atPath: sourceFile) {
                // project/Source/whatever doesn't exist: try project/whatever
                sourceFile = (projectDir as NSString).appendingPathComponent(originalSourceFile)
                sourceFile = (sourceFile as NSString).standardizingPath

                if !FileManager.default.fileExists(atPath: sourceFile) {
                    // If neither exists, use project/Source/whatever by default
                    sourceFile = (sourceDir as NSString).appendingPathComponent(originalSourceFile)
                    sourceFile = (sourceFile as NSString).standardizingPath
                }
            }
        }

        if (sourceFile as NSString).isAbsolutePath {
            // Absolute path
            if ((sourceFile as NSString).deletingLastPathComponent as NSString).standardizingPath == sourceDir {
                return _sourceFiles?[(sourceFile as NSString).lastPathComponent]
            }

            if !FileManager.default.fileExists(atPath: sourceFile) {
                return nil
            }

            // Read text
            let data = NSData(contentsOfFile: sourceFile) as Data? ?? Data()
            var textData = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String?

            if textData == nil {
                // Sometimes a file cannot be interpreted using UTF-8: present something in this case
                textData = NSString(data: data, encoding: String.Encoding.isoLatin1.rawValue) as String?
            }

            let text = storage(withString: textData ?? "",
                               forFilename: sourceFile,
                               undoManager: undoManager)
            otherTexts.append(text)
            return text
        }

        return _sourceFiles?[sourceFile]
    }
}
