//
//  IFSourceSharedActions.m
//  Inform
//
//  Created by Andrew Hunter on Wed Aug 27 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "IFIntelSymbol.h"
#import "IFIntelFile.h"
#import "IFSyntaxManager.h"
#import "IFInform7MutableString.h"
#import "IFSourceSharedActions.h"
#import "IFUtility.h"

#pragma mark Preferences

@implementation IFSourceSharedActions

+ (void) initialize {
	// Register our preferences
}

#pragma mark - Initialistion

- (instancetype) init {
    self = [super init];

    if (self) {
    }

    return self;
}


#pragma mark - View selection functions

#pragma mark Menu options

- (NSRange) shiftRange: (NSRange) range
			 inStorage: (NSTextStorage*) storage
			  tabStops: (int) tabStops {
	int x;

	if (tabStops == 0) return NSMakeRange(0,0);
	
	NSMutableString* string = storage.mutableString;
	
	// Find the start of the line preceeding range
	while (range.location > 0 &&
		   [string characterAtIndex: range.location-1] != '\n') {
		range.location--;
		range.length++;
	}
	
	// Tab string to insert
	NSString* tabs = nil;
	if (tabStops > 0) {
        tabs = [@"" stringByPaddingToLength:tabStops withString: @"\t" startingAtIndex:0];
	}
	
	// Shift each line in turn
	if (range.length == 0) range.length = 1;
	for (x=0; x<range.length;) {
		// Position at x should be the start of a line
		if (tabStops > 0) {
			// Insert tabs at the start of this line
			[string replaceCharactersInRange: NSMakeRange(range.location+x, 0)
								  withString: tabs];

			range.length += tabStops;	// String is longer
			x += tabStops;				// No need to process these again when finding the next line
		} else if (tabStops < 0) {
			// Delete tabs at the start of this line
			
			// Work out how many tabs to delete
			int nTabs = 0;
			while (range.location+x+nTabs < string.length &&
				   nTabs < -tabStops &&
				   [string characterAtIndex: range.location+x+nTabs] == '\t')
				nTabs++;
			
			// Delete them
			[string deleteCharactersInRange: NSMakeRange(range.location+x, nTabs)];
			
			range.length += tabStops;	// String is shorter
		}
		
		// Find the next line
		x++;
		while (x < range.length &&
			   range.location+x < string.length &&
			   [string characterAtIndex: range.location+x-1] != '\n')
			x++;
		
		if (range.location+x >= string.length) break;
	}
	
	return range;
}

- (NSRange) shiftRangeLeftInDocument: (NSDocument*) document
                               range: (NSRange) range
                             storage: (NSTextStorage*) textStorage {
	// These functions are used to help with undo
	[textStorage beginEditing];
	
	// This works because the undo manager for the text view will always be the same as the undo manager for this controller
	// If this ever changes, you will need to rewrite this somehow
	NSUndoManager* undo = document.undoManager;
	[undo setActionName: [IFUtility localizedString: @"Shift Left"]];
	NSRange newRange = [self shiftRange: range
							  inStorage: textStorage
							   tabStops: -1];
	[[undo prepareWithInvocationTarget: self] shiftRangeRightInDocument: document
                                                                  range: newRange
                                                                storage: textStorage];
	[textStorage endEditing];
	
	return newRange;
}


- (NSRange) shiftRangeRightInDocument: (NSDocument*) document
                                range: (NSRange) range
                              storage: (NSTextStorage*) textStorage {
	// These functions are used to help with undo
	[textStorage beginEditing];
	
	// This works because the undo manager for the text view will always be the same as the undo manager for this controller
	// If this ever changes, you will need to rewrite this somehow
	NSUndoManager* undo = document.undoManager;
	[undo setActionName: [IFUtility localizedString: @"Shift Right"]];
	NSRange newRange = [self shiftRange: range
							  inStorage: textStorage
							   tabStops: 1];
	[[undo prepareWithInvocationTarget: self] shiftRangeLeftInDocument: document
                                                                 range: newRange
                                                               storage: textStorage];

	[textStorage endEditing];
	
	return newRange;
}

- (void) shiftLeftTextViewInDocument: (NSDocument*) document
                            textView: (NSTextView*) textView {
	NSTextStorage* storage = textView.textStorage;
	NSRange       selRange = [textView selectedRange];
	
	if (!storage) {
        return;
    }
	
	NSRange newRange = [self shiftRangeLeftInDocument: document
                                                range: selRange
                                              storage: storage];
	
	[textView setSelectedRange: newRange];
}

- (void) shiftRightTextViewInDocument: (NSDocument*) document
                             textView: (NSTextView*) textView {
	NSTextStorage* storage = textView.textStorage;
	NSRange       selRange = [textView selectedRange];
	
	if (!storage) {
        return;
    }
	
	NSRange newRange = [self shiftRangeRightInDocument: document
                                                 range: selRange
                                               storage: storage];
	
	[textView setSelectedRange: newRange];
}

- (void) renumberSectionsInDocument: (NSDocument*) document
                           textView: (NSTextView*) textView {

	NSTextStorage* storage = (NSTextStorage*)textView.textStorage;
	
	if ([IFSyntaxManager intelligenceDataForStorage: storage] == nil) {
        return;		// Also can't do this if we haven't actually gathered any data
    }

	NSUndoManager* undo = document.undoManager;
	
	// Renumber each section stored in the intelligence data
	IFIntelFile*   intel   = [IFSyntaxManager intelligenceDataForStorage: storage];
	IFIntelSymbol* section = intel.firstSymbol;

	[undo beginUndoGrouping];
	[storage beginEditing];
	
	// Collect the lines that need to be renumbered
	NSMutableArray* linesToRenumber = [[NSMutableArray alloc] init];
	
	while (section != nil) {
		if (section.level > 0) {
			NSUInteger lineNumber = [intel lineForSymbol: section];
			
			IFIntelSymbol* lastSection = section.previousSibling;
			NSUInteger lastLineNumber = [intel lineForSymbol: lastSection];

			[linesToRenumber addObject: @[@(lineNumber), @(lastLineNumber)]];
		}
		
		section = section.nextSymbol;
	}

	// Renumber these lines
	// Note that if these operations were concatenated, we'd have a bug as
    // the intelligence would sometimes delete symbols
	for( NSArray* lineInfo in linesToRenumber ) {
		int lineNumber = [lineInfo[0] intValue];
		NSString* sectionLine = [IFSyntaxManager textForLineWithStorage: storage lineNumber: lineNumber];
		NSArray*  words = [sectionLine componentsSeparatedByString: @" "];
		
		int sectionNumber = words.count>1 ? [words[1] intValue] : 0;
		
		if (sectionNumber > 0) {
			// This looks like something we can renumber... Get the preceding number
			int lastLineNumber = [lineInfo[1] intValue];
			NSArray* lastWords = [[IFSyntaxManager textForLineWithStorage: storage lineNumber: lastLineNumber] componentsSeparatedByString: @" "];

			int lastSectionNumber = lastWords.count>1?[lastWords[1] intValue]:0;
			
			if (lastSectionNumber >= 0 && lastSectionNumber+1 != sectionNumber) {
				// This section needs renumbering
				NSMutableArray* newWords = [words mutableCopy];

				if (newWords.count == 2) {
					// Must be followed by a newline
					newWords[1] = [NSString stringWithFormat: @"%i\n", lastSectionNumber+1];
				} else {
					// Must not be followed by a newline
					newWords[1] = [NSString stringWithFormat: @"%i", lastSectionNumber+1];
				}

				// OK, replace the text
				[IFSyntaxManager replaceLineWithStorage: storage
                                             lineNumber: lineNumber
                                               withLine: [newWords componentsJoinedByString: @" "]];
			}
		}
	}

	[storage endEditing];
	[undo endUndoGrouping];
}

#pragma mark Commenting out source

- (void) undoCommentOutInDocument: (NSDocument*) document
                            range: (NSRange) range
                   originalString: (NSString*) original
                        inStorage: (NSTextStorage*) storage {
	// Fetch the string that now occupies the specified range
	NSString* replacing = [storage.string substringWithRange: range];
	
	// Replace the range with the original string
	[storage.mutableString replaceCharactersInRange: range
										   withString: original];
	
	// Generate a new undo action
	NSUndoManager* undo = document.undoManager;
	[[undo prepareWithInvocationTarget: self] undoCommentOutInDocument: document
                                                                 range: NSMakeRange(range.location, original.length)
                                                        originalString: replacing
                                                             inStorage: storage];
}

- (void) commentOutSelectionInDocument: (NSDocument*) document
                              textView: (NSTextView*) textView {
	NSTextStorage*	storage			= textView.textStorage;
	NSRange			commentRange	= [textView selectedRange];
	NSString*		original		= [storage.string substringWithRange: commentRange];
	
	// Comment out the region
	bool changed = [storage.mutableString commentOutInform7: &commentRange];
	
    if( changed ) {
        // Select the newly commented region
        [textView setSelectedRange: commentRange];
        
        // Generate an undo action
        NSUndoManager* undo = document.undoManager;
        [[undo prepareWithInvocationTarget: self] undoCommentOutInDocument: document
                                                                     range: commentRange
                                                            originalString: original
                                                                 inStorage: storage];
    }
}

- (void) uncommentSelectionInDocument: (NSDocument*) document
                             textView: (NSTextView*) textView {
	NSTextStorage*	storage			= textView.textStorage;
	NSRange			commentRange	= [textView selectedRange];
	NSString*		original		= [storage.string substringWithRange: commentRange];

	// Uncomment the region
	bool changed = [storage.mutableString removeCommentsInform7: &commentRange];

    if( changed ) {
        // Select the newly uncommented region
        [textView setSelectedRange: commentRange];

        // Generate an undo action
        NSUndoManager* undo = document.undoManager;
        [[undo prepareWithInvocationTarget: self] undoCommentOutInDocument: document
                                                                     range: commentRange
                                                            originalString: original
                                                                 inStorage: storage];
    }
}

@end
