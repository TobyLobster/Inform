//
//  IFSingleFile.h
//  Inform
//
//  Created by Andrew Hunter on 23/06/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Extensions and other lone files are stored by this document class.
///
@interface IFSingleFile : NSDocument

#pragma mark Retrieving document data
/// The contents of the file
@property (nonatomic, readonly, strong) NSTextStorage *storage;
/// \c YES if this file is read-only
@property (nonatomic, getter=isReadOnly, readonly) BOOL readOnly;

/// The range to select when the file's window is made
@property (nonatomic) NSRange initialSelectionRange;


@end

NS_ASSUME_NONNULL_END
