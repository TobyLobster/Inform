//
//  CblorbProblem.swift
//  Inform
//
//  Created by C.W. Betts on 11/26/21.
//

import Foundation

/// Class that deals with problems with the cblorb stage.
class CBlorbProblem: NSObject, IFCompilerProblemHandler {
	/// `nil`, or the build directory that should be inspected for problem files.
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

/// Class that deals with problems with the Inform 6 stage of a Natural Inform build process
class Inform6Problem: NSObject, IFCompilerProblemHandler {
	func urlForProblem(errorCode: Int32) -> URL? {
		return URL(string: "inform:/ErrorI6.html")
	}
}

/// Class that deals with problems with the Natural Inform compiler
class NaturalProblem: NSObject, IFCompilerProblemHandler {
	func urlForProblem(errorCode: Int32) -> URL? {
		// Code 0 indicates compiler succeeded
		// Code 1 indicates a 'normal' failure
		// We ignore negative return codes should they occur
		guard errorCode > 1 else {
			return nil
		}
		
		// Default error page is Error0
		var fileURLString = "inform:/Error0.html"
		
		// See if we've got a file for this specific error code
		let specificFile = String(format: "Error%i", errorCode)
		let resourcePath = Bundle.main.path(forResource: specificFile, ofType: "html")
		
		if let resourcePath = resourcePath, FileManager.default.fileExists(atPath: resourcePath) {
			fileURLString = String(format: "inform:/%@.html", specificFile)
		}
		
		// Return the result
		return URL(string: fileURLString)
	}
}
