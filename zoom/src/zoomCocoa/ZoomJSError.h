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
@interface ZoomJSError : NSObject

/// The last error to occur
@property (copy, nullable) NSString *lastError;

@end
