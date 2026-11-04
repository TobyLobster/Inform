//
//  IFRuntimeErrorParser.m
//  Inform
//
//  Created by Andrew Hunter on 10/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFRuntimeErrorParser.h"
#import "IFUtility.h"


@implementation IFRuntimeErrorParser {
    /// The character accumulator
    NSMutableString* accumulator;
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		accumulator = [[NSMutableString alloc] init];
	}
	
	return self;
}

@synthesize delegate;

- (void) outputText: (NSString*) outputText {
	// The story's output arrives in pieces of any size, so collect it into lines, and check
	// each line once it is complete
	[accumulator appendString: outputText];

	NSRange newline;
	while ((newline = [accumulator rangeOfString: @"\n"]).location != NSNotFound) {
		NSString* line = [accumulator substringToIndex: newline.location];
		[accumulator deleteCharactersInRange: NSMakeRange(0, NSMaxRange(newline))];
		[self checkLine: line];
	}
}

/// Tells the delegate if this line of the story's output announces a run-time problem
- (void) checkLine: (NSString*) line {
	// Scan for '*** Run-time problem XX' at the beginning of a line: this indicates that runtime problem XX
	// has occured (and we should probably be showing file RTP_XX.html). A story compiled with
	// debugging follows it with ': ' and the folder holding the problem's explanation.

    NSString* problemType = nil;
    NSString* directory = nil;

    NSTextCheckingResult *match = [IFUtility findMatch: @"^\\*\\*\\* Run-time problem\\s+([^\\s:]+)(?::\\s*(.*))?$" inText: line];
    if (match) {
        problemType = [line substringWithRange: [match rangeAtIndex:1]];
        NSTextCheckingResult *oldStyleMatches = [IFUtility findMatch: @"P\\d+" inText: problemType];
        if ((oldStyleMatches == nil) && ([match rangeAtIndex: 2].location != NSNotFound)) {
            directory   = [line substringWithRange: [match rangeAtIndex:2]];
        }
    }

	if (problemType != nil) {
		// A problem was encountered: inform the delegate
        if ([delegate respondsToSelector: @selector(runtimeError:inDirectory:)]) {
            [delegate runtimeError: problemType inDirectory: directory];
		}
	}
}

// Notifications about events that have occured in the view (when using this automation object for output)

/// Text has arrived at the specified text buffer window (from the game)
- (void) receivedCharacters: (NSString*) characters
					 window: (int) windowNumber
				   fromView: (GlkView*) view {
	[self outputText: characters];
}

/// The user has typed the specified string into the specified window (which is any window that is waiting for input)
- (void) userTyped: (NSString*) userInput
			window: (int) windowNumber
		 lineInput: (BOOL) isLineInput
		  fromView: (GlkView*) view {
}

/// The user has clicked at a specified position in the given window
- (void) userClickedAtXPos: (int) xpos
					  ypos: (int) ypos
					window: (int) windowNumber
				  fromView: (GlkView*) view {
}

- (void) viewWaiting: (GlkView*) view {
    
}

// Using this automation object for input

- (void) viewIsWaitingForInput: (GlkView*) view {
	
}

@end
