//
//  IFSkeinReportItemView.swift
//  Inform
//
//  Created by Toby Nelson in 2015
//

import AppKit

private let kBlessButtonWidth: CGFloat  = 13.0
private let kBlessButtonHeight: CGFloat = 13.0

@objc @implementation extension IFSkeinReportItemView {
    let textView: NSTextView
    var uniqueId: UInt = 0
    private final var _textHeight: CGFloat = 0
    var topBorderHeight: CGFloat = 0
    let blessButton: IFSkeinBlessButton

    var textHeight: CGFloat {
        return _textHeight
    }

    public override init(frame: NSRect) {
        blessButton = IFSkeinBlessButton()
        // TextKit 1: with TextKit 2, sizeToFit doesn't reliably resize the view when the text changes
        textView    = NSTextView(usingTextLayoutManager: false)

        super.init(frame: frame)

        setUpSubviews()
    }

    /// Swift requires this, as `init(frame:)` is overridden. Nothing decodes this view, but it's set up as
    /// `init(frame:)` sets it up.
    public required init?(coder: NSCoder) {
        blessButton = IFSkeinBlessButton()
        textView    = NSTextView(usingTextLayoutManager: false)

        super.init(coder: coder)

        setUpSubviews()
    }

    private final func setUpSubviews() {
        textView.isEditable                       = false
        textView.drawsBackground                  = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled         = false
        textView.isHorizontallyResizable          = false
        textView.isVerticallyResizable            = true
        textView.textContainerInset               = NSZeroSize
        textView.minSize                          = NSSize(width: kSkeinReportWidth - kSkeinReportInsideLeftBorder
                                                                      - kSkeinReportInsideRightBorder,
                                                           height: 1.0)
        addSubview(textView)
        addSubview(blessButton)
    }

    func setAttributedString(_ string: NSAttributedString,
                             forceChange: Bool) {
        frame = NSRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        if !forceChange && textView.textStorage?.isEqual(to: string) == true {
            return
        }
        textView.textStorage?.setAttributedString(string)
        textView.sizeToFit()

        _textHeight = textView.frame.size.height

        frame = NSRect(x: frame.origin.x,
                       y: frame.origin.y,
                       width: kSkeinReportWidth,
                       height: _textHeight)
    }

    public override var frame: NSRect {
        get {
            return super.frame
        }
        set {
            super.frame = newValue

            textView.frame = NSRect(x: kSkeinReportInsideLeftBorder,
                                    y: newValue.size.height - topBorderHeight - _textHeight,
                                    width: kSkeinReportWidth - kSkeinReportInsideLeftBorder
                                           - kSkeinReportInsideRightBorder,
                                    height: _textHeight)
            blessButton.frame = NSRect(x: newValue.size.width - kBlessButtonWidth - 1.0,
                                       y: 1.0,
                                       width: kBlessButtonWidth,
                                       height: kBlessButtonHeight)
        }
    }
}
