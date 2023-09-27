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
	// Scan for '*** Run-time problem XX' at the beginning of a line: this indicates that runtime problem XX
	// has occured (and we should probably be showing file RTP_XX.html)

    NSString* problemType = nil;
    NSString* directory = nil;

    NSTextCheckingResult *match = [IFUtility findMatch: @"^\\*\\*\\* Run-time problem\\s+([^\\s]+):\\s*(.*)$" inText: outputText];
    if (match) {
        problemType = [outputText substringWithRange: [match rangeAtIndex:1]];
        NSTextCheckingResult *oldStyleMatches = [IFUtility findMatch: @"P\\d+" inText: problemType];
        if (oldStyleMatches == nil) {
            directory   = [outputText substringWithRange: [match rangeAtIndex:2]];
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
	unichar* chrs = malloc(sizeof(unichar)*characters.length);
    if( chrs != NULL ) {
        [characters getCharacters: chrs];
        
        int start = 0;
        int x;
        for (x=0; x<characters.length; x++) {
            if (chrs[x] == '\n') {
                [accumulator appendString: [NSString stringWithCharacters: chrs + start
                                                                   length: x - start]];
                
                [self outputText: accumulator];
                accumulator = [[NSMutableString alloc] init];
                start = x;
            }
        }
        [accumulator appendString: [NSString stringWithCharacters: chrs + start
                                                           length: x - start]];
        
        [accumulator appendString: characters];
        [self outputText: characters];
    }
    free(chrs);
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
