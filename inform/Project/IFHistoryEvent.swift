//
//  IFHistoryEvent.swift
//  Inform
//
//  Created by Andrew Hunter on 23/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is IFHistoryEvent in IFHistoryEvent.h.
//

import Foundation

@objc @implementation extension IFHistoryEvent {
    /// The actions to perform when this history item is replayed, in order
    private final var actions: [() -> Void] = []

    // MARK: - Initialisation

    override init() {
        super.init()
    }

    // MARK: - Recording

    func addAction(_ action: @escaping () -> Void) {
        actions.append(action)
    }

    // MARK: - Replaying

    func replay() {
        for action in actions {
            action()
        }
    }
}
