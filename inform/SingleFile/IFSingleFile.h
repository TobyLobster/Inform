//
//  IFSingleFile.h
//  Inform
//
//  Created by Andrew Hunter on 23/06/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFSyntaxTypes.h"

//
// Extensions and other lone files are stored by this document class.
//
@interface IFSingleFile : NSDocument {
	NSTextStorage* fileStorage;						// The contents of the file
	NSStringEncoding fileEncoding;					// The encoding used for the file
    NSRange initialSelectionRange;
}

// Retrieving document data
- (NSTextStorage*) storage;							// The contents of the file
- (BOOL) isReadOnly;								// YES if this file is read-only
- (NSRange) initialSelectionRange;

-(void) setInitialSelectionRange: (NSRange) range;

@end
