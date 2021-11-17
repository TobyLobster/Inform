//
//  ZoomSkeinItem+Pasteboard.m
//  ZoomView
//
//  Created by C.W. Betts on 10/1/21.
//

#import "ZoomSkeinItem+Pasteboard.h"
#import "ZoomSkeinView.h"

@implementation ZoomSkeinItem (Pasteboard)

- (nullable id)pasteboardPropertyListForType:(nonnull NSPasteboardType)type {
	if ([type isEqualToString:ZoomSkeinItemPboardType]) {
		return [NSKeyedArchiver archivedDataWithRootObject: self
									 requiringSecureCoding: YES
													 error: NULL];
	}
	return nil;
}

- (nonnull NSArray<NSPasteboardType> *)writableTypesForPasteboard:(nonnull NSPasteboard *)pasteboard {
	if ([[pasteboard name] isEqualToString:NSPasteboardNameDrag]) {
		return @[ZoomSkeinItemPboardType];
	}
	return @[];
}

@end
