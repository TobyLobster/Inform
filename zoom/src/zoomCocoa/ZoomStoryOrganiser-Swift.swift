//
//  ZoomStoryOrganiser.swift
//  Zoom
//
//  Created by C.W. Betts on 10/28/21.
//

import Foundation
import ZoomPlugIns
import ZoomPlugIns.ZoomPlugInManager
import ZoomView

extension ZoomStoryOrganiser {
	@objc(frontispieceForBlorb:)
	static func frontispiece(for decodedFile: ZoomBlorbFile) -> NSImage? {
		var coverPictureNumber: Int32 = -1
		
		// Try to retrieve the frontispiece tag (overrides metadata if present)
		guard let front = decodedFile.dataForChunk(withType: "Fspc"), front.count >= 4 else {
			return nil
		}
		do {
			let fpc = front[0 ..< 4]

			let val = UInt32(fpc[0]) << 24 | UInt32(fpc[1]) << 16 | UInt32(fpc[2]) << 8 | UInt32(fpc[3])
			coverPictureNumber = Int32(bitPattern: val)
		}
		
		if coverPictureNumber >= 0 {
			// Attempt to retrieve the cover picture image
			guard let coverPictureData = decodedFile.imageData(withNumber: coverPictureNumber),
				  let coverPicture = NSImage(data: coverPictureData) else {
					  return nil
				  }
			
			// Sometimes the image size and pixel size do not match up
			let coverRep = coverPicture.representations.first!
			let pixSize = NSSize(width: coverRep.pixelsWide, height: coverRep.pixelsHigh)
			
			if pixSize != .zero, // just in case it's a vector format. Not likely, but still possible.
			   pixSize != coverPicture.size {
				coverPicture.size = pixSize
			}
			
			return coverPicture
		}
		
		return nil
	}

	@available(*, deprecated, message: "Use +frontispieceForURL: or frontispiece(for:) instead")
	@objc(frontispieceForFile:)
	static func frontispiece(forFile filename: String) -> NSImage? {
		return frontispiece(for: URL(fileURLWithPath: filename))
	}

	@objc(frontispieceForURL:)
	static func frontispiece(for filename: URL) -> NSImage? {
		// First see if a plugin can provide the image...
		if let plugin = ZoomPlugInManager.shared.instance(for: filename),
			let res = plugin.coverImage {
			return res
		}
		
		// Then try using the standard blorb decoder
		if let decodedFile = try? ZoomBlorbFile(contentsOf: filename) {
			return frontispiece(for: decodedFile)
		}
		
		return nil
	 }
}
