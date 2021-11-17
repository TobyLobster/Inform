//
//  HQImageView.swift
//  Zoom
//
//  Created by C.W. Betts on 10/2/21.
//

import Cocoa

/// Class whose sole purpose is to increase the rendering quality of NSImageView
class HQImageView: NSImageView {

    override func draw(_ dirtyRect: NSRect) {
		// Set the graphics context image rendering quality
		NSGraphicsContext.current?.imageInterpolation = .high
		
		// The rest is up to the image view (or would be, if it didn't promptly turn this off again)
		// super.draw(dirtyRect)

		let bounds = self.bounds
		let imageSize = self.image?.size ?? .zero
		var imageBounds = bounds
		let scaleFactor1 = (imageBounds.height - 6) / imageSize.height
		let scaleFactor2 = (imageBounds.width - 6) / imageSize.width
		
		let scaleFactor = min(scaleFactor1, scaleFactor2)
		
		imageBounds.size.width = imageSize.width * scaleFactor
		imageBounds.size.height = imageSize.height * scaleFactor
		
		imageBounds.origin.x += (bounds.width - imageBounds.width) / 2
		imageBounds.origin.y += bounds.height - imageBounds.height
		
		self.image?.draw(in: imageBounds,
						 from: .zero,
						 operation: .sourceOver,
						 fraction: 1)
    }
    
	override func mouseDown(with event: NSEvent) {
		if event.clickCount == 2, let target = self.target {
			sendAction(action, to: target)
		}
	}
}
