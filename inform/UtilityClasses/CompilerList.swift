//
//  CompilerList.swift
//  Inform
//
//  Created by C.W. Betts on 11/19/21.
//

import Foundation

@objcMembers final class CompilerList: NSObject {
	static let compilerList = readCompilerRetrospectiveFile()
	
	static func readCompilerRetrospectiveFile() -> [IFCompilerListEntry] {
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
		
		return matches.map { match -> IFCompilerListEntry in
			let identifier = getString(in: match, capture: 1)
			let displayName = getString(in: match, capture: 2)
			let description = getString(in: match, capture: 3)
			
			return IFCompilerListEntry(id: identifier, displayName: displayName, description: description)
		}
	}
	
	private override init() {}
}
