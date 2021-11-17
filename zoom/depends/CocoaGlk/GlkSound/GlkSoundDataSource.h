//
//  GlkSoundDataSource.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 28/06/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


///
/// Protocol implemented by classes that can act as a data source for a CocoaGlk sound module
///
@protocol GlkSoundDataSource <NSObject>

/// An NSString indicating the format of the data contained in this source
@property (readonly, copy) NSString *soundFormat;

/// The length of the data in this source
@property (readonly) NSInteger length;

/// Retrieves data for the specified region of this source
- (NSData*) dataForRegion: (NSRange) region;

@end
