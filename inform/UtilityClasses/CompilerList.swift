//
//  CompilerList.swift
//  Inform
//
//  Created by C.W. Betts on 11/19/21.
//

import Foundation

@objcMembers final class CompilerList: NSObject {
	static let compilerList = readCompilerRetrospectiveFile()
	
	static func readCompilerRetrospectiveFile() -> [Entry] {
		let fileURL = Bundle.main.url(forResource: "retrospective", withExtension: "txt", subdirectory: "App/Compilers")!
		let contents = try! String(contentsOf: fileURL, encoding: .utf8)
		
		let regex = try! NSRegularExpression(pattern: #"\s*\'(.*?)\'\s*,\s*\'(.*?)\'\s*,\s*\'(.*?)\'\s*"#, options: [.useUnicodeWordBoundaries])
		let matches = regex.matches(in: contents, options: [], range: NSRange(contents.startIndex ..< contents.endIndex, in: contents))
		
		func getString(in match: NSTextCheckingResult, capture: Int) -> String {
			let theNSRange = match.range(at: capture)
			let theRange = Range(theNSRange, in: contents)!
			let theString = contents[theRange]
			return String(theString)
		}
		
		return matches.map { match -> Entry in
			let identifier = getString(in: match, capture: 1)
			let displayName = getString(in: match, capture: 2)
			let description = getString(in: match, capture: 3)
			
			return Entry(identifier: identifier, displayName: displayName, description: description)
		}
	}
	
	private override init() {}
	
	@objcMembers @objc(IFCompilerListEntry) class Entry: NSObject {
		@objc(id) let identifier: String

		let displayName: String

		override var description: String {
			return ourdescription
		}

		private let ourdescription: String
		
		init(identifier: String, displayName: String, description: String) {
			self.identifier = identifier
			self.displayName = displayName
			ourdescription = description
		}
	}

}
