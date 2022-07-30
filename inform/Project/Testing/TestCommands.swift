//
//  TestCommands.swift
//  Inform
//
//  Created by C.W. Betts on 11/19/21.
//

import Foundation
import ZoomView.Protocols

class TestCommands: NSObject, ZoomViewInputSource {
    private var commands: [String]
    
    @objc init(commands: [String]) {
        self.commands = commands
    }
    
    func nextCommand() -> String? {
        return commands.popLast()
    }
    
    var disableMorePrompt: Bool {
        return true
    }
}
