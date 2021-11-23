//
//  ThinSplitView.swift
//  Inform
//
//  Created by C.W. Betts on 11/22/21.
//

import AppKit

/// Subclass a split view to make a thinner divider
class ThinSplitView : NSSplitView {
    override var dividerThickness: CGFloat {
        return 3
    }
}
