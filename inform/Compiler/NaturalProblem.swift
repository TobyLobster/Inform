//
//  NaturalProblem.swift
//  Inform
//
//  Created by C.W. Betts on 11/26/21.
//

import Foundation

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
