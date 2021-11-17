//
//  ZoomQuest.swift
//  Quest
//
//  Created by C.W. Betts on 10/3/21.
//

import Cocoa
import ZoomPlugIns.ZoomPlugIn.Glk
import ZoomPlugIns.ZoomPlugIn.Glk.WindowController
import ZoomPlugIns.ZoomPlugIn.Glk.Document
import ZoomPlugIns

private var casHeader: Data = {
	let strData = "QCGF002"
	return strData.data(using: .ascii)!
}()

private let extensions = ["cas", "asl"]

final public class Quest: ZoomGlkPlugIn {
	public override class var pluginVersion: String {
		return (Bundle(for: Quest.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String)!
	}
	
	public override class var pluginDescription: String {
		return "Plays Quest 4 files"
	}
	
	public override class var pluginAuthor: String {
		return #"C.W. "Madd the Sane" Betts"#
	}
	
	public override class var canLoadSavegames: Bool {
		return false
	}
	
	public override class func canRun(_ url: URL) -> Bool {
		guard extensions.contains(url.pathExtension.lowercased()) else {
			return false
		}
		guard (try? url.checkResourceIsReachable()) ?? false else {
			return true
		}
		
		guard let hand = try? FileHandle(forReadingFrom: url) else {
			return false
		}
		
		var datToTest: Data
		
		if #available(macOS 10.15.4, *) {
			guard let outDat = try? hand.read(upToCount: 7), outDat.count == 7 else {
				return false
			}
			datToTest = outDat
		} else {
			let outDat = hand.readData(ofLength: 7)
			guard outDat.count == 7 else {
				return false
			}
			datToTest = outDat
		}
		if datToTest == casHeader {
			return true
		}
		
		return url.pathExtension.lowercased() == "asl"
	}
	
	public override class var supportedFileTypes: [String] {
		return ["uk.co.textadventures.asl", "uk.co.textadventures.cas", "asl", "cas"]
	}
	
	public override init?(url gameFile: URL) {
		super.init(url: gameFile)
		clientPath = Bundle(for: Quest.self).path(forAuxiliaryExecutable: "geas")
	}
	
	public override func defaultMetadata() throws -> ZoomStory {
		let fileData = try Data(contentsOf: gameURL)
		let id = ZoomStoryID(for: gameURL) ?? ZoomStoryID(data: fileData)!
		let fileString: String
		
		switch gameURL.pathExtension.lowercased() {
		case "asl":
			guard let fstr2 = String(data: fileData, encoding: .utf8) else {
				return try super.defaultMetadata()
			}
			fileString = fstr2
			
		case "cas":
			let lines = CASDecompile(fileData)
			fileString = lines.joined(separator: "\n")
			
		default:
			throw NSError(domain: NSOSStatusErrorDomain, code: paramErr, userInfo: [NSURLErrorKey: gameURL])
		}
		let meta = ZoomMetadata()
		let story = meta.findOrCreateStory(id)
		
		let gameRegex = try! NSRegularExpression(pattern: #"define game <([^<>\n]+)>"#, options: [])
		guard let firstMatch = gameRegex.firstMatch(in: fileString, options: [], range: NSRange(fileString.startIndex ..< fileString.endIndex, in: fileString)) else {
			return try super.defaultMetadata()
		}
		let firstString = fileString[Range(firstMatch.range(at: 1), in: fileString)!]
		story.title = String(firstString)
		let autorRegex = try! NSRegularExpression(pattern: #"game author <([^<>\n]+)>"#, options: [])
		if let authorMatch = autorRegex.firstMatch(in: fileString, options: [], range: NSRange(fileString.startIndex ..< fileString.endIndex, in: fileString)) {
			let authorSubstring = fileString[Range(authorMatch.range(at: 1), in: fileString)!]
			let authorString = String(authorSubstring)
			story.author = authorString
		}
		return story
	}
	
	public override var coverImage: NSImage? {
		return nil
	}
}
