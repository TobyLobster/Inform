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

    // MARK: - Find in Files

    @objc(selectMatchAtRange:inContext:afterAnchor:completionHandler:)
    func selectMatch(at range: NSRange,
                     inContext context: String,
                     afterAnchor anchor: String?,
                     completionHandler: (@MainActor @Sendable (Bool) -> Void)?) {
        // The page's text after the anchor, without its whitespace, with the node and offset of each character
        let script = """
            const whitespace = /\\s/;
            let start = document.body;
            if (anchor) {
                start = document.getElementById(anchor) || document.getElementsByName(anchor)[0] || document.body;
            }
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
                acceptNode: node => node.parentElement.closest("script, style, noscript")
                    ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT
            });
            walker.currentNode = start;
            let text = "";
            const nodes = [];
            const offsets = [];
            for (let node = walker.nextNode(); node; node = walker.nextNode()) {
                const data = node.data;
                for (let i = 0; i < data.length; i++) {
                    if (!whitespace.test(data[i])) {
                        text += data[i];
                        nodes.push(node);
                        offsets.push(i);
                    }
                }
            }

            // The match in its context, or failing that, on its own
            const strip = string => string.replace(/\\s+/g, "");
            const before = strip(context.substring(0, location));
            const match = strip(context.substring(location, location + length));
            const after = strip(context.substring(location + length));
            if (match.length === 0) {
                return false;
            }
            let found = text.indexOf(before + match + after);
            if (found >= 0) {
                found += before.length;
            } else {
                found = text.indexOf(match);
            }
            if (found < 0) {
                return false;
            }

            const last = found + match.length - 1;
            const range = document.createRange();
            range.setStart(nodes[found], offsets[found]);
            range.setEnd(nodes[last], offsets[last] + 1);
            const selection = window.getSelection();
            selection.removeAllRanges();
            selection.addRange(range);
            nodes[found].parentElement.scrollIntoView({ block: "center" });
            return true;
            """
        let arguments: [String: Any] = ["context": context,
                                        "location": range.location,
                                        "length": range.length,
                                        "anchor": anchor ?? ""]
        callAsyncJavaScript(script, arguments: arguments, in: nil, in: .defaultClient) { result in
            completionHandler?((try? result.get() as? Bool) ?? false)
        }
    }
}
