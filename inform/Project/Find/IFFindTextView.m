//
//  IFFindTextView.m
//  Inform
//
//  Created by Andrew Hunter on 05/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import "IFFindTextView.h"
#import "IFFindController.h"
#import "IFFindResult.h"
#import "IFAppDelegate.h"
#import "IFFindInFiles.h"
#import "IFScanner.h"
#import "IFUtility.h"

#include <wctype.h>

static NSArray* lastFoundGroups;

@implementation NSTextView(IFFindTextView)

+(void)initialize {
    lastFoundGroups = nil;
}

- (NSRange) find: (NSString*) phrase
			type: (IFFindType) type
	   direction: (int) direction 
	   fromPoint: (NSUInteger) point
       hasLooped: (bool*) hasLoopedOut
regexFoundGroups: (NSArray*__strong*) foundGroupsOut {

    NSRange result;
    *hasLoopedOut = false;
    if( foundGroupsOut != nil ) {
        *foundGroupsOut = nil;
    }

    if( direction > 0 ) {
        // Forwards search
        result = [IFScanner findNextMatch: phrase
                                  storage: self.textStorage.string
                                 position: point
                                  options: type
                         regexFoundGroups: foundGroupsOut];
        if( result.location == NSNotFound ) {
            *hasLoopedOut = true;
            // Wrap around if we didn't start at the beginning
            if( point > 0 ) {
                point = 0;
                result = [IFScanner findNextMatch: phrase
                                          storage: self.textStorage.string
                                         position: point
                                          options: type
                                 regexFoundGroups: foundGroupsOut];
            }
        }
    }
    else {
        // Backwards search
        result = [IFScanner findPreviousMatch: phrase
                                      storage: self.textStorage.string
                                     position: point
                                      options: type
                             regexFoundGroups: foundGroupsOut];
        if( result.location == NSNotFound ) {
            *hasLoopedOut = true;
            // Wrap around if we didn't start at the end
            if( point < self.textStorage.string.length ) {
                point = (int) self.textStorage.string.length;
                result = [IFScanner findPreviousMatch: phrase
                                              storage: self.textStorage.string
                                             position: point
                                              options: type
                                     regexFoundGroups: foundGroupsOut];
            }
        }
    }
    NSAssert(result.location == NSNotFound || result.length > 0, @"Found match of length zero");
    return result;
}

#pragma mark - Basic interface

- (void) findNextMatch:	(NSString*) match
				ofType: (IFFindType) type
     completionHandler: (void (^)(bool result))completionHandler {
    // Start after the current selection
	NSUInteger matchPos = [self selectedRange].location + [self selectedRange].length;

    // If we have just moved beyond the end of the text, start at the beginning
    if( matchPos >= self.textStorage.string.length ) {
        matchPos = 0;
    }
    bool hasLooped;
	NSRange matchRange = [self find: match
							   type: type
						  direction: 1
						  fromPoint: matchPos
                          hasLooped: &hasLooped
                   regexFoundGroups: &lastFoundGroups];

	if (matchRange.location != NSNotFound) {
		[self scrollRangeToVisible: matchRange];
		[self setSelectedRange: matchRange];
        [self showFindIndicatorForRange: matchRange];
        if (completionHandler != nil) {
            completionHandler(true);
        }
	} else {
		NSBeep();
        if (completionHandler != nil) {
            completionHandler(false);
        }
	}
}

- (void) findPreviousMatch: (NSString*) match
					ofType: (IFFindType) type
         completionHandler: (void (^)(bool result))completionHandler {
    // Start searching at the previous character
    NSUInteger matchPos;
    
    if( [self selectedRange].location > 0 ) {
        matchPos = [self selectedRange].location - 1;
    }
    else {
        // If we have just moved before the start of the text, start searching at the end
        matchPos = self.textStorage.string.length - 1;
    }

    bool hasLooped;
	NSRange matchRange =  [self find: match
								type: type
						   direction: -1
						   fromPoint: matchPos
                           hasLooped: &hasLooped
                    regexFoundGroups: &lastFoundGroups];
	
	if (matchRange.location != NSNotFound) {
		[self scrollRangeToVisible: matchRange];
		[self setSelectedRange: matchRange];
        [self showFindIndicatorForRange: matchRange];
        if (completionHandler != nil) {
            completionHandler(true);
        }
	} else {
		NSBeep();
        if (completionHandler != nil) {
            completionHandler(false);
        }
	}
}

- (BOOL) canUseFindType: (IFFindType) find {
	return YES;
}

- (void) currentSelectionForFindWithCompletionHandler:(void (^)(NSString*))completionHandler {
    if (completionHandler != nil) {
        completionHandler([self.string substringWithRange: [self selectedRange]]);
    }
}

#pragma mark - 'Find all'

- (void) highlightFindResult: (IFFindResult*) result {
	NSRange matchRange = result.fileRange;

	[self scrollRangeToVisible: matchRange];
	[self setSelectedRange: matchRange];
    [self showFindIndicatorForRange: matchRange];
}

- (NSArray*) findAllMatches: (NSString*) match
					 ofType: (IFFindType) type
                 inLocation: (IFFindLocation) location
		   inFindController: (IFFindController*) controller
			 withIdentifier: (id) identifier {
	// Do nothing if no phrase is supplied
	if (match.length == 0) return nil;

	// Prepare to match all of the results
	NSUInteger pos = 0;
    bool hasLooped = false;
	NSRange nextMatch;
	NSMutableArray* results = [[NSMutableArray alloc] init];
    NSArray*        foundGroups;
	
	for (;;) {
        //
		// Find the next match.
        //
		nextMatch = [self find: match
						  type: type
					 direction: 1
					 fromPoint: pos
                     hasLooped: &hasLooped
              regexFoundGroups: &foundGroups];

		// Stop when we reach the end of the text
        if( hasLooped ) {
            break;
        }

        //
		// If we found a match, add it to the list of results
        //
		if (nextMatch.location != NSNotFound) {
            //
            // Calculate context (text around the match to display in the search results)
            //
            NSRange contextRange;
            NSString* context = [IFFindInFiles getContextFromText: self.textStorage.string
                                                     withLocation: nextMatch.location
                                                        andLength: nextMatch.length
                                              findingContextRange: &contextRange];

            //
            // Store result
            //
            IFFindResult* result = [[IFFindResult alloc] initWithFilepath: nil
                                                              rangeInFile: nextMatch
                                                      documentDisplayName: nil
                                                         documentSortName: nil
                                                             locationType: IFFindCurrentPage
                                                                  context: context
                                                             contextRange: contextRange
                                                              exampleName: @""
                                                         exampleAnchorTag: @""
                                                            codeAnchorTag: @""
                                                      definitionAnchorTag: @""
                                                         regexFoundGroups: foundGroups];
            [results addObject:result];

            // Remember the last set of group results, so that "replace and find" can use it.
            lastFoundGroups = [foundGroups copy];
            
			// Move to the next position
			pos = nextMatch.location + 1;
		} else {
			break;
		}
	};

	return results;
}

#pragma mark - Replace

- (NSArray*) lastFoundGroups {
    return lastFoundGroups;
}

- (void) replaceFoundWith: (NSString*) match
					range: (NSRange) selected {
	NSString* previousValue = [self.string substringWithRange: selected];
	
	[self.textStorage replaceCharactersInRange: selected
									  withString: match];
	selected.length = match.length;
	[self setSelectedRange: selected];
	
	// Create an undo action for this replacement
	[self.undoManager setActionName: [IFUtility localizedString: @"Replace"]];
	[[self.undoManager prepareWithInvocationTarget: self] replaceFoundWith: previousValue
																	   range: selected];
}

- (void) replaceFoundWith: (NSString*) match {
	NSRange selected = [self selectedRange];
	[self replaceFoundWith: match
					 range: selected];
}

- (void) beginReplaceAll: (IFFindController*) sender {
	// Begin an undo action for this operation
	[self.undoManager beginUndoGrouping];
	[self.undoManager setActionName: [IFUtility localizedString: @"Replace All"]];
}

- (void) finishedReplaceAll: (IFFindController*) sender {
	// Finished with the replace all operation
	[self.undoManager endUndoGrouping];
}


- (void) replaceFindAllResult: (NSString*) match 
						range: (NSRange) selected {
	NSString* previousValue = [self.string substringWithRange: selected];
	
	[self.textStorage replaceCharactersInRange: selected
									  withString: match];
	selected.length = match.length;
	[self setSelectedRange: selected];

	// Create an undo action for this replacement
	[[self.undoManager prepareWithInvocationTarget: self] replaceFindAllResult: previousValue
																		   range: selected];
}

- (IFFindResult*) replaceFindAllResult: (IFFindResult*) result
							withString: (NSString*) replacement 
								offset: (int*) offset {
	// Get the original match
	NSRange matchRange = result.fileRange;
	matchRange.location += *offset;
	NSString* originalMatch = [result.context substringWithRange: result.contextRange];
	
	// Check that the user hasn't edited the text since the match was made
	if (![[self.textStorage.string substringWithRange: matchRange] isEqualToString: originalMatch]) {
		return nil;
	}

	// Update the context to create a new match
	NSRange contextRange = result.contextRange;
	NSString* oldContext = result.context;
	NSString* newContext = [NSString stringWithFormat: @"%@%@%@",
							[oldContext substringToIndex: contextRange.location],
							replacement,
							[oldContext substringFromIndex: contextRange.location + contextRange.length]];
	NSRange newContextRange = result.contextRange;
	newContextRange.length = replacement.length;
	
	NSRange newMatchRange = matchRange;
	newMatchRange.length = replacement.length;

	IFFindResult* newResult = [[IFFindResult alloc]  initWithFilepath: result.filepath
                                                          rangeInFile: newMatchRange
                                                  documentDisplayName: result.documentDisplayName
                                                     documentSortName: result.documentSortName
                                                         locationType: result.locationType
                                                              context: newContext
                                                         contextRange: newContextRange
                                                          exampleName: result.exampleName
                                                     exampleAnchorTag: result.exampleAnchorTag
                                                        codeAnchorTag: result.codeAnchorTag
                                                  definitionAnchorTag: result.definitionAnchorTag
                                                     regexFoundGroups: result.regexFoundGroups];

	// Perform the replacement
	[self replaceFindAllResult: replacement
						 range: matchRange];
	
	// Update the offset so future matches are replaced correctly
	*offset += (int)replacement.length - (int)originalMatch.length;

	return newResult;
}

@end
