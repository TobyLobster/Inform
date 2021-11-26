//
//  Inform6Problem.swift
//  Inform
//
//  Created by C.W. Betts on 11/26/21.
//

import Foundation

/// Class that deals with problems with the Inform 6 stage of a Natural Inform build process
class Inform6Problem: NSObject, IFCompilerProblemHandler {
    func urlForProblem(errorCode: Int32) -> URL? {
        return URL(string: "inform:/ErrorI6.html")
    }
}
