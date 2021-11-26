//
//  CblorbProblem.swift
//  Inform
//
//  Created by C.W. Betts on 11/26/21.
//

import Foundation

/// Class that deals with problems with the cblorb stage.
class CBlorbProblem: NSObject, IFCompilerProblemHandler {
	/// nil, or the build directory that should be inspected for problem files
	private let buildDir: URL?
	
	@objc(initWithBuildDirectoryURL:)
	init(buildDirectory: URL?) {
		buildDir = buildDirectory
	}
	
	@objc(initWithBuildDir:)
	convenience init(buildDir: String?) {
		let anURL: URL?
		if let buildDir = buildDir {
			anURL = URL(fileURLWithPath: buildDir)
		} else {
			anURL = nil
		}
		self.init(buildDirectory: anURL)
	}
	
	func urlForProblem(errorCode: Int32) -> URL? {
		// If a build directory is supplied, then look there for the error file
		if let buildDir = buildDir {
			let errorPath = buildDir.appendingPathComponent("StatusCblorb.html", isDirectory: false)
			
			if (try? errorPath.checkResourceIsReachable()) ?? false {
				return errorPath
			}
		}
		
		// Otherwise, use the default
		return URL(string: "inform:/ErrorCblorb.html")
	}
	
	var urlForSuccess: URL? {
		// If a build directory is supplied, then look there for the error file
		if let buildDir = buildDir {
			let errorPath = buildDir.appendingPathComponent("StatusCblorb.html", isDirectory: false)
			
			if (try? errorPath.checkResourceIsReachable()) ?? false {
				return errorPath
			}
		}

		// Otherwise, use the default
		return URL(string: "inform:/GoodCblorb.html")
	}
}
