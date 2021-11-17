//
//  ZoomCollapsableView.swift
//  Zoom
//
//  Created by C.W. Betts on 10/3/21.
//

import Cocoa

private let BORDER: CGFloat = 4.0
private let FONTSIZE: CGFloat = 14


class CollapsableView: NSView {
	private var views = [(view: NSView, title: String, state: Bool)]()
	private var rearranging = false
	private var reiterate = false
	private var iterationCount = 0
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		
		afterInitSetup()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		
		afterInitSetup()
	}
	
	private func afterInitSetup() {
		postsFrameChangedNotifications = true
		NotificationCenter.default.addObserver(self,
											   selector: #selector(self.subviewFrameChanged(_:)),
											   name: NSView.frameDidChangeNotification,
											   object: self)
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	override var isOpaque: Bool {
		return true
	}
	
	override func draw(_ dirtyRect: NSRect) {
		let titleFont = NSFont.boldSystemFont(ofSize: FONTSIZE)
		let backgroundColor = NSColor.controlBackgroundColor
		let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont,
															  .foregroundColor: NSColor.controlTextColor,
															  .backgroundColor: backgroundColor]
		
		backgroundColor.set()
		dirtyRect.fill()
		
		// Draw the titles and frames
		let frameColor = NSColor(deviceRed: 0.5,
								 green: 0.5,
								 blue: 0.5,
								 alpha: 1)
		
		for (thisView, thisTitle, shown) in views {
			guard shown else {
				continue
			}
			
			let titleSize = thisTitle.size(withAttributes: titleAttributes)
			let thisFrame = thisView.frame
			
			var ypos = thisFrame.origin.y;
			var titleHeight: CGFloat
			
			if thisTitle != "" {
				titleHeight = titleSize.height * 1.2
			} else {
				titleHeight = titleSize.height * 0.2
			}
			ypos -= titleHeight;
			
			// Draw the border rect
			let borderRect = NSRect(x: floor(BORDER)+0.5, y: floor(ypos)+0.5,
									width: bounds.size.width-(BORDER*2), height: thisFrame.size.height + titleHeight + (BORDER));
			frameColor.set()
			NSBezierPath.stroke(borderRect)
			
			// IMPLEMENT ME: draw the show/hide triangle (or maybe add this as a view?)
			
			// Draw the title
			if thisTitle != "" {
				thisTitle.draw(at: NSPoint(x: BORDER*2, y: ypos + 2 + titleSize.height * 0.1),
							   withAttributes: titleAttributes)
			}

		}
		
		super.draw(dirtyRect)
	}
	
	// MARK: - Management
	
	@objc func removeAllSubviews() {
		for (subview, _, _) in views {
			subview.removeFromSuperview()
		}
		
		views.removeAll()
		
		rearrangeSubviews()
	}
	
	@objc func setSubview(_ subview: NSView, isHidden: Bool) {
		let subviewIndex = views.firstIndex { view in
			return view.view === subview
		}
		
		if let subviewIndex = subviewIndex {
			views[subviewIndex].state = !isHidden
		}
		
		rearrangeSubviews()
	}
	
	@objc func addSubview(_ subview: NSView, withTitle title: String) {
		views.append((subview, title, false))
		
		// Set the width appropriately
		var viewFrame = subview.frame
		viewFrame.size.width = bounds.width - (BORDER*4)
		subview.autoresizingMask = []
		subview.frame = viewFrame
		subview.needsDisplay = true

		// Rearrange the views
		rearrangeSubviews()
		
		// Receive notifications about this view
		subview.postsFrameChangedNotifications = true
		NotificationCenter.default.addObserver(self,
											   selector: #selector(self.subviewFrameChanged(_:)),
											   name: NSView.frameDidChangeNotification,
											   object: subview)
	}
	
	@objc func rearrangeSubviews() {
		reiterate = true
		guard !rearranging else {
			return
		}
		
		// Mark as rearranging (stop re-entrance)
		rearranging = true
		reiterate = false
		
		// If we iterate deeply, then the scrollbar becomes mandatory
		var parentView = superview
		var scrollView: NSScrollView?
		while parentView != nil && !(parentView is NSScrollView) {
			parentView = parentView?.superview
		}
		
		if let parentView = parentView as? NSScrollView {
			scrollView = parentView
			scrollView?.autohidesScrollers = false
		} else {
			scrollView = nil
		}
		
		if parentView == nil {
			parentView = self
		}
		
		parentView?.needsDisplay = false
		needsDisplay = false
		
		// Rearrange the views as necessary
		var needsRedrawing = false
		
		var oldBounds = NSRect.zero
		var newBounds = bounds
		
		var bestWidth: CGFloat = 0
		var newHeight: CGFloat = 0
		
		let titleFont = NSFont.boldSystemFont(ofSize: FONTSIZE)
		let titleHeight = titleFont.ascender - titleFont.descender
		
		oldBounds = newBounds
		
		// First stage: resize all subviews to be the correct width
		bestWidth = oldBounds.width - (BORDER * 4)
		
		for (subview, _, shown) in views {
			var viewFrame = subview.frame
			if (shown && viewFrame.size.width != bestWidth) {
				needsRedrawing = true
				viewFrame.size.width = bestWidth
				subview.setFrameSize(viewFrame.size)
				subview.needsDisplay = false
			}
		}
		
		// Second stage: calculate our new height (and resize appropriately)
		newHeight = BORDER;
		for (subview, title, shown) in views {
			let viewFrame = subview.frame
			
			if shown {
				if title != "" {
					newHeight += titleHeight * 1.2;
				} else {
					newHeight += titleHeight * 0.2;
				}
				newHeight += viewFrame.size.height;
				newHeight += BORDER*2;
			}
		}

		oldBounds.size.height = floor(newHeight)
		self.setFrameSize(oldBounds.size)
		
		// Loop until our width settles down
		newBounds = bounds
		
		// Stage three: Position the views appropriately
		var ypos = BORDER
		for (subview, title, shown) in views {
			var viewFrame = subview.frame
			
			if (shown) {
				if title != "" {
					ypos += titleHeight * 1.2;
				} else {
					ypos += titleHeight * 0.2;
				}
			}
			
			if (subview.superview !== self || !shown) {
				if subview.superview != nil {
					subview.removeFromSuperview()
				}
				if (shown) {
					addSubview(subview)
				}
			}
			
			if (shown) {
				if (viewFrame.origin.x != BORDER*2 ||
					viewFrame.origin.y != floor(ypos)) {
					viewFrame.origin.x = BORDER*2;
					viewFrame.origin.y = floor(ypos)
				
					subview.setFrameOrigin(viewFrame.origin)
					subview.needsDisplay = false
					needsRedrawing = true;
				}

				ypos += viewFrame.size.height;
				ypos += BORDER*2;
			}
		}
		
		// Show/hide the vertical scroll bar as necessary
		if let scrollView = scrollView, !reiterate {
			var showVerticalBar = false;
			let barVisible = scrollView.hasVerticalScroller
			
			// Decide if we need to show a scrollbar or not
			let docView = scrollView.contentView
			let maxHeight = docView.bounds.height
			
			if (newHeight > maxHeight || iterationCount > 1) {
				showVerticalBar = true
			} else {
				showVerticalBar = false
			}
			
			if showVerticalBar != barVisible {
				// If iteration count goes high, then only ever show the bar, never hide it
				if !showVerticalBar {
					// Hide the scrollbar
					scrollView.hasVerticalScroller = false
					
					iterationCount += 1
					rearranging = false
					rearrangeSubviews()
					iterationCount -= 1
					return;
				} else {
					// Show the scrollbar
					scrollView.hasVerticalScroller = true

					iterationCount += 1
					rearranging = false
					rearrangeSubviews()
					iterationCount -= 1
					return;
				}
			}
		}
		
		if (reiterate) {
			// Something has resized and messed up our beautiful arrangement!
			rearranging = false
			rearrangeSubviews()
			return;
		}
		
		// Final stage: tidy up, redraw if necessary
		parentView?.display()
		
		needsDisplay = false
		for subview in views {
			subview.view.needsDisplay = false
		}
			
		rearranging = false
	}
	
	override var isFlipped: Bool {
		return true
	}
	
	@objc func subviewFrameChanged(_ not: Notification) {
		reiterate = true
		guard !rearranging else {
			return
		}
		
		if RunLoop.current.currentMode == .eventTracking {
			rearrangeSubviews()
		} else {
			rearranging = true
			RunLoop.current.perform(#selector(self.finishChangingFrames(_:)),
									target: self,
									argument: self,
									order: 32,
									modes: [.default, .modalPanel, .eventTracking])
		}
	}
	
	@objc private func finishChangingFrames(_ sender: Any?) {
		for (view, _, _) in views {
			var viewFrame = view.frame
			if viewFrame.size.width != bounds.size.width - (BORDER*4) {
				viewFrame.size.width = bounds.size.width - (BORDER*4)
				view.frame = viewFrame
				view.needsDisplay = true
				needsDisplay = true
			}
		}
		
		rearranging = false
		
		rearrangeSubviews()
	}

	@objc func startRearranging() {
		rearranging = true
	}

	@objc func finishRearranging() {
		rearranging = false
		
		rearrangeSubviews()
	}
}
