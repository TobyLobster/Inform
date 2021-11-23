//
//  IFSingleFile.h
//  Inform
//
//  Created by Andrew Hunter on 23/06/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

///
/// Extensions and other lone files are stored by this document class.
///
@interface IFSingleFile : NSDocument

#pragma mark Retrieving document data
/// The contents of the file
@property (atomic, readonly, copy) NSTextStorage *storage;
/// \c YES if this file is read-only
@property (atomic, getter=isReadOnly, readonly) BOOL readOnly;

@property (atomic) NSRange initialSelectionRange;


@end
