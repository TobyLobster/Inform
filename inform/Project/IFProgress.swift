//
//  IFProgress.swift
//  Inform
//
//  Created by Andrew Hunter on 28/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFProgress.h.
//

import Foundation

@objc @implementation
extension IFProgress {
    // Constants
    let priority: Int32
    let showsProgressBar: Bool
    let canCancel: Bool

    // Current state
    private final var _percentage: CGFloat
    private final var _inProgress: Bool

    private final var _cancelled: Bool
    private final var cancelActionSelector: Selector?
    private final var cancelActionObject: Any?

    // Delegate
    weak var delegate: IFProgressDelegate?

    // MARK: - Initialisation

    init(priority aPriority: Int32,
         showsProgressBar aShowsProgressBar: Bool,
         canCancel aCanCancel: Bool) {
        priority = aPriority
        showsProgressBar = aShowsProgressBar
        canCancel = aCanCancel
        _percentage = 0
        _inProgress = false
        _cancelled = false
        super.init()
    }

    // MARK: - Setting the current progress

    var percentage: CGFloat {
        get {
            return _percentage
        }
        set {
            _percentage = newValue

            delegate?.progressIndicator?(self, percentage: newValue)
        }
    }

    var message: String? {
        didSet {
            delegate?.progressIndicator?(self, message: message)
        }
    }

    func startStory() {
        delegate?.progressIndicatorStartStory?(self)
    }

    func stopStory() {
        delegate?.progressIndicatorStopStory?(self)
    }

    @objc(startProgress)
    func start() {
        _inProgress = true
        _percentage = 0
        delegate?.progressIndicatorStart?(self)
    }

    @objc(stopProgress)
    func stop() {
        _inProgress = false
        _percentage = 0
        delegate?.progressIndicatorStop?(self)
    }

    // Cancelling
    @objc(setCancelAction:forObject:)
    func setCancelAction(_ selector: Selector, for object: Any) {
        cancelActionSelector = selector
        cancelActionObject = object
    }

    @objc(cancelProgress)
    func cancel() {
        _cancelled = true
        // (The objects given are all NSObjects, which have performSelectorOnMainThread:)
        if let cancelActionSelector, let cancelActionObject = cancelActionObject as? NSObject {
            if cancelActionObject.responds(to: cancelActionSelector) {
                cancelActionObject.performSelector(onMainThread: cancelActionSelector,
                                                   with: cancelActionObject,
                                                   waitUntilDone: true)
            }
        }
    }

    @objc(cancelled)
    var isCancelled: Bool {
        @objc(isCancelled)
        get {
            return _cancelled
        }
    }

    @objc(inProgress)
    var isInProgress: Bool {
        @objc(isInProgress)
        get {
            return _inProgress
        }
    }
}
