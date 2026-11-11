//
//  IFProjectTypes.swift
//  Inform
//
//  Translated from Objective-C in November 2026. The interface is still IFProjectTypes.h.
//

import Foundation

@objc @implementation
extension IFProjectTypes {

    class func encoding(forFilename filename: String) -> UInt {
        let extn = (filename as NSString).pathExtension.lowercased()

        if extn == "inf" ||
           extn == "i6" ||
           extn == "icl" ||
           extn == "txt" ||
           extn == "h" {
            // Latin1 encoding
            return String.Encoding.isoLatin1.rawValue
        }

        if extn == "ni" ||
           extn == "i7" ||
           extn == "i7x" ||
           extn == "w" ||
           extn == "html" ||
           extn == "htm" ||
           extn == "" {
            // UTF8 encoding
            return String.Encoding.utf8.rawValue
        }

        // Unknown file type, assuming UTF8 encoding
        NSLog("Couldn't find encoding for file %@, assuming UTF8", filename)
        return String.Encoding.utf8.rawValue
    }

    class func informVersion(forFilename filename: String) -> IFInformVersion {
        let extn = (filename as NSString).pathExtension.lowercased()

        if extn == "inf" ||
           extn == "i6" ||
           extn == "h" {
            // Inform 6 file
            return .version6
        }

        if extn == "ni" ||
           extn == "i7" ||
           extn == "i7x" ||
           extn == "" {
            // Natural Inform file
            return .version7
        }

        return .versionUnknown
    }

    @objc(fileTypeFromString:)
    class func fileType(from typeName: String) -> IFFileType {
        let typeName = typeName.lowercased()

        if typeName == "inform project file" ||
           typeName == "inform project" ||
           typeName == "org.inform-fiction.project" {
            return .inform7Project
        }

        if typeName == "org.inform-fiction.xproject" {
            return .inform7ExtensionProject
        }

        //
        // Inform 6 source file
        //
        if typeName == "inform 6 source file" ||
           typeName == "org.inform-fiction.source.inform6" {
            return .inform6SourceFile
        }
        //
        // Inform 7 source file
        //
        if typeName == "natural inform source file" ||
           typeName == "inform 7 source file" ||
           typeName == "org.inform-fiction.source.inform7" {
            return .inform7SourceFile
        }

        //
        // Inform 6 ICL file
        //
        if typeName == "inform control language file" ||
           typeName == "public.c-header" {
            return .inform6ICLFile
        }

        //
        // Inform 7 Extension File
        //
        if typeName == "inform 7 extension" ||
           typeName == "org.inform-fiction.inform7.extension" {
            return .inform7ExtensionFile
        }

        NSLog("Unknown file type '%@' found", typeName)
        return .unknown
    }

    class func highlighterType(forFilename filename: String) -> IFHighlightType {
        let version = IFProjectTypes.informVersion(forFilename: filename)
        switch version {
        case .version6:       return .inform6   // Inform 6 file
        case .version7:       return .inform7   // Inform 7 file
        case .versionUnknown: return .none
        @unknown default:     return .none
        }
    }

    @MainActor class func intelligence(forFilename filename: String) -> IFSyntaxIntelligence? {
        let version = IFProjectTypes.informVersion(forFilename: filename)
        switch version {
        case .version6:       return nil                // Inform 6 file (no intelligence yet)
        case .version7:       return IFNaturalIntel()   // Inform 7 file
        case .versionUnknown: return nil                // Unknown file type - no intelligence
        @unknown default:     break
        }

        // No intelligence
        return nil
    }
}
