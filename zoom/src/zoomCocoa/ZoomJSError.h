//
//  ZoomJSError.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 25/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

///
/// A javascript object used to report errors to Zoom
///
@interface ZoomJSError : NSObject {
	NSString* lastError;							// The last error to occur
}

- (NSString*) lastError;
- (void) setLastError: (NSString*) lastError;

@end
