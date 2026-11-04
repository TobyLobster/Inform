//
//  IFRecentFileCell.swift
//  Inform
//
//  Created by Toby Nelson on 27/09/2023.
//  (Converted from Objective C version by Toby Nelson 2014)
//

import Foundation
import os

let imageSize = 16
let borderWidth = 5.0
let borderHeight = 0.0
let recentFilesTabWidth = 130

class IFRecentFileCell : NSTextFieldCell {

    /*
    func copyWithZone(zone:NSZone!) -> AnyObject! {
        let cell:IFRecentFileCell! = NSTextFieldCell.copyWithZone(zone) as? IFRecentFileCell
        if cell == nil {
            return nil
        }

        cell.image = self.image

        return cell
    }
    */

    override func copy(with zone: NSZone? = nil) -> Any {
        let cell = super.copy(with: zone) as? IFRecentFileCell
        cell?.image = self.image

        return cell as Any
    }

    func attributedStringValue() -> NSAttributedString! {
        var astr:NSAttributedString? = nil

        let title:String! = self.stringValue
        if (title != nil) {
            let textColour = self.isHighlighted ? NSColor.selectedTextColor : NSColor.textColor
            let paragraph = NSMutableParagraphStyle()
            let tab:NSTextTab! = NSTextTab(type: .leftTabStopType,
                                       location: CGFloat(recentFilesTabWidth))
            paragraph.tabStops = [tab]
            paragraph.lineBreakMode = .byClipping

            let attrs = [NSAttributedString.Key.foregroundColor: textColour,
                          NSAttributedString.Key.paragraphStyle: paragraph]

            astr = NSAttributedString(string:title, attributes:attrs)
        }

        return astr
    }

    override func imageRect(forBounds:NSRect) -> NSRect {
        var imageRect = forBounds

        imageRect.size.width = CGFloat(imageSize)
        imageRect.size.height = CGFloat(imageSize)

        return imageRect
    }

    override func titleRect(forBounds:NSRect) -> NSRect {
        var titleRect:NSRect = forBounds

        titleRect.origin.x += CGFloat(forBounds.height + borderWidth)
        titleRect.origin.y += CGFloat(borderHeight)

        let title:NSAttributedString? = self.attributedStringValue()
        titleRect.size = title?.size() ?? NSZeroSize

        let maxX:CGFloat = NSMaxX(forBounds)
        var maxWidth:CGFloat = maxX - NSMinX(titleRect)
        if maxWidth < 0 {
            maxWidth = 0
        }

        titleRect.size.width = min(NSWidth(titleRect), maxWidth)

        return titleRect
    }

    override func drawInterior(withFrame cellFrame:NSRect, in controlView:NSView?) {
        let imageRect = self.imageRect(forBounds: cellFrame)
        if (image != nil) {
            image!.draw(   in: imageRect,
                         from: NSZeroRect,
                    operation: .sourceOver,
                     fraction: 1.0,
               respectFlipped: true,
                        hints: nil)
        } else {
            let path = NSBezierPath(rect: imageRect)
            NSColor.gray.set()
            path.fill()
        }

        let titleRect = self.titleRect(forBounds: cellFrame)
        let aTitle = self.attributedStringValue()!
        if aTitle.length > 0 {
            aTitle.draw(in: titleRect)
        }
    }
}
