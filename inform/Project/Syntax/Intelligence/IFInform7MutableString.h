//
//  IFInform7MutableString.h
//  Inform
//
//  Created by Andrew Hunter on 04/10/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


///
/// Extensions to the NSMutableString class that allow manipulating I7 code
///
@interface NSMutableString(IFInform7MutableString)

///
/// Comments out a region in the string using Inform 7 syntax. Returns the new extent of the
/// range.
///
- (bool) commentOutInform7: (NSRange*) rangeInOut;

///
/// Removes I7 comments from the specified range. Returns the new extent of the range.
///
- (bool) removeCommentsInform7: (NSRange*) rangeInOut;

@end
