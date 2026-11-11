//
//  IFFindWebView.swift
//  Inform
//
//  Created by Andrew Hunter on 23/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

import WebKit

@objc(IFFindWebView) @implementation extension WKWebView {

    // MARK: - Find

    @objc(findNextMatch:ofType:completionHandler:)
    func findNextMatch(_ match: String,
                       of type: IFFindType,
                       completionHandler: (@MainActor @Sendable (Bool) -> Void)?) {
        let insensitive = (type.rawValue & IFFindType.caseInsensitive.rawValue) != 0

        let configuration = WKFindConfiguration()
        configuration.backwards = false
        configuration.caseSensitive = !insensitive
        configuration.wraps = true

        find(match, configuration: configuration) { result in
            completionHandler?(result.matchFound)
        }
    }

    @objc(findPreviousMatch:ofType:completionHandler:)
    func findPreviousMatch(_ match: String,
                           of type: IFFindType,
                           completionHandler: (@MainActor @Sendable (Bool) -> Void)?) {
        let insensitive = (type.rawValue & IFFindType.caseInsensitive.rawValue) != 0

        let configuration = WKFindConfiguration()
        configuration.backwards = true
        configuration.caseSensitive = !insensitive
        configuration.wraps = true

        find(match, configuration: configuration) { result in
            completionHandler?(result.matchFound)
        }
    }

    @objc(canUseFindType:)
    func canUse(_ find: IFFindType) -> Bool {
        switch find {
        case .contains:
            return true

        case .beginsWith, .completeWord, .regexp:
            return false
        default:
            return false
        }
    }

    func currentSelectionForFind(completionHandler: @escaping @MainActor @Sendable (String?) -> Void) {
        let script = "window.getSelection().toString()"
        evaluateJavaScript(script) { selectedString, error in
            if error == nil {
                completionHandler(selectedString as? String)
            } else {
                NSSound.beep()
                completionHandler(nil)
            }
        }
    }
}
