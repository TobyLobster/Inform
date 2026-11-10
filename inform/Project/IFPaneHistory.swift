//
//  IFPaneHistory.swift
//  Inform
//
//  Moved out of IFProjectPane in November 2026.
//

import Foundation

@objc @implementation extension IFPaneHistory {
    /// The history actions for this object
    private final var history: [IFHistoryEvent] = []
    /// The last history event created
    private final var lastEvent: IFHistoryEvent?
    /// The position that we are in the history
    private final var historyPos = -1
    /// If true, then new history items are not created
    private final var replaying = false

    /// Called when the history has changed
    private final let changed: () -> Void

    init(changeHandler: @escaping () -> Void) {
        changed = changeHandler
        super.init()
    }

    var canGoBackwards: Bool {
        return historyPos > 0
    }

    var canGoForwards: Bool {
        return historyPos < history.count - 1
    }

    @objc private final func clearLastEvent() {
        lastEvent = nil
    }

    private final func addHistoryEvent(_ newEvent: IFHistoryEvent) {
        NSLog("HISTORY: Pane History (%@): (addHistoryEvent) %@", self, newEvent)

        // If we've gone backwards in the history, then remove the 'forward' history items
        if historyPos != history.count - 1 {
            history.removeSubrange((historyPos + 1)...)
        }

        // Add the new history item
        history.append(newEvent)
        historyPos += 1

        // Record it as the last event
        if lastEvent == nil {
            RunLoop.current.perform(#selector(clearLastEvent),
                                    target: self,
                                    argument: nil,
                                    order: 99,
                                    modes: [.default])
        }

        lastEvent = newEvent

        changed()
    }

    @objc(eventForObject:)
    func event(for object: Any) -> IFHistoryEvent? {
        if replaying {
            return nil
        }

        let event: IFHistoryEvent
        if let lastEvent {
            event = lastEvent
        } else {
            // Construct a new event based on this obejct
            let newEvent = IFHistoryEvent(object: object)
            addHistoryEvent(newEvent)

            event = newEvent
        }

        return event
    }

    func goBackwards() {
        if historyPos <= 0 {
            return
        }

        replaying = true
        history[historyPos - 1].replay()
        historyPos -= 1
        replaying = false

        changed()
    }

    func goForwards() {
        if historyPos >= history.count - 1 {
            return
        }

        replaying = true
        history[historyPos + 1].replay()
        historyPos += 1
        replaying = false

        changed()
    }

    func clear() {
        history.removeAll()
        lastEvent = nil
        historyPos = -1
    }
}
