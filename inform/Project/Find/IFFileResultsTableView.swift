//
//  IFFileResultsTableView.swift
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

import Foundation

@objc protocol IFFindClickableTableViewDelegate {
    func tableView(_: NSTableView, didClickRow: NSInteger)
}

class IFFindResultsTableView: NSTableView {
    @IBOutlet public var extendedDelegate:IFFindClickableTableViewDelegate!

    override func mouseDown(with: NSEvent) {
        let globalLocation:NSPoint = with.locationInWindow
        let localLocation:NSPoint = self.convert(globalLocation, from:nil)
        let clickedRow:Int = self.row(at: localLocation)

        super.mouseDown(with: with)

        if clickedRow != -1 {
            self.extendedDelegate?.tableView(self, didClickRow: clickedRow as NSInteger)
        }
        self.window?.makeKeyAndOrderFront(self)
    }
}
