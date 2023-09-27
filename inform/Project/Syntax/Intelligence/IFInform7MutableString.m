//
//  IFInform7MutableString.m
//  Inform
//
//  Created by Andrew Hunter on 04/10/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//

#import "IFInform7MutableString.h"

@implementation NSMutableString(IFInform7MutableString)

// Given a range, is it valid for commenting / uncommenting code?
- (bool) checkValidRangeForChangingCommenting: (NSRange*) range
                                 commentDepth: (int*) commentDepthOut {
    // Make sure we are in range
    *range = NSIntersectionRange(*range, NSMakeRange(0, self.length));
	
    // Make sure something is selected
	if (range->length == 0) {
		return false;
	}
    
	int commentDepth	= 0;
	bool inString       = false;
    
    // Parse up to the starting point...
    for (int index = 0; index < range->location; index++) {
        int chr = [self characterAtIndex: index];
        
        // Check for start or end of string
        if ((chr == '"') || (chr == 0x201C) || (chr == 0x201D)) {
            inString = !inString;
        } else if (!inString) {
            // Check for start or end comment
            if (chr == '[') {
                commentDepth++;
            } else if ((chr == ']') && (commentDepth > 0)) {
                commentDepth--;
            }
        }
    }
    
    // If we are in a string, don't try to comment out code
    if( inString ) {
        return false;
    }
    
    // Scan the range to make sure we are not spanning different comment levels...
    int rangeCommentDepth = commentDepth;
    for(NSUInteger index = range->location; index < (range->location + range->length); index++ ) {
        int chr = [self characterAtIndex: index];
        
        if ((chr == '"') || (chr == 0x201C) || (chr == 0x201D)) {
            inString = !inString;
        } else if (!inString) {
            // Check for start or end comment
            if (chr == '[') {
                rangeCommentDepth++;
            } else if ((chr == ']') && (rangeCommentDepth > 0)) {
                rangeCommentDepth--;
                
                // If we close a comment so the depth goes below the start depth, don't try to comment it out.
                if( rangeCommentDepth < commentDepth ) {
                    return false;
                }
            }
        }
    }
    
    // If we are in a string, don't try to comment out code
    if( inString ) {
        return false;
    }
    
    // If the comment depth changes, don't try to comment out code
    if( rangeCommentDepth != commentDepth ) {
        return false;
    }

    *commentDepthOut = commentDepth;
    return true;
}

- (bool) commentOutInform7: (NSRange*) range {
    // Make sure we are in a valid range
    int commentDepth;
    bool isValidRange = [self checkValidRangeForChangingCommenting: range
                                                      commentDepth: &commentDepth];
    if( !isValidRange ) {
        return false;
    }

    // All clear to make the change - comment out
    [self insertString: @"]" atIndex: range->location + range->length];
    [self insertString: @"[" atIndex: range->location];
    range->length += 2;

    return true;
}


///
/// Removes I7 comments from the specified range
///
- (bool) removeCommentsInform7: (NSRange*) range {
    // Make sure we are in a valid range
    int commentDepth;
    bool isValidRange = [self checkValidRangeForChangingCommenting: range
                                                      commentDepth: &commentDepth];
    if( !isValidRange ) {
        return false;
    }

    // All clear to make the change - uncomment
    NSUInteger end = range->location + range->length - 1;
    if(([self characterAtIndex: range->location] == '[') &&
       ([self characterAtIndex: end] == ']')) {
        [self deleteCharactersInRange: NSMakeRange(end, 1)];
        [self deleteCharactersInRange: NSMakeRange(range->location, 1)];
        range->length -= 2;
        return true;
    }

    if( commentDepth > 0 ) {
        [self insertString: @"[" atIndex: range->location + range->length];
        [self insertString: @"]" atIndex: range->location];
        range->length += 2;

        return true;
    }
    return false;
}

@end
