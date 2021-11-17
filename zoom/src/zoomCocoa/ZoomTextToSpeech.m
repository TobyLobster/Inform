//
//  ZoomTextToSpeech.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 21/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomTextToSpeech.h"

#include <ApplicationServices/ApplicationServices.h>

#undef UseCocoaSpeech

#ifndef UseCocoaSpeech
static SpeechChannel channel = nil;
#endif

@implementation ZoomTextToSpeech

+ (void) initialize {
#ifndef UseCocoaSpeech
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NewSpeechChannel(NULL, &channel);
	});
#endif
}

- (id) init {
#ifndef UseCocoaSpeech
	if (channel == nil) return nil;
#endif
	
	self = [super init];
	
	if (self) {
		text = [[NSMutableString alloc] init];
		
#ifdef UseCocoaSpeech
		synth = [[NSSpeechSynthesizer alloc] initWithVoice: [NSSpeechSynthesizer defaultVoice]];
#endif
	}
	
	return self;
}

#pragma mark - Direct output

- (void) inputCommand: (NSString*) command {
	[text appendString: @"\n\n"];
	[text appendString: command];
	[text appendString: @"\n\n"];
}

- (void) inputCharacter: (__unused NSString*) character {
}

- (void) outputText:     (NSString*) outputText {
	[text appendString: outputText];
}

#pragma mark - Status notifications

- (void) zoomWaitingForInput {
	if (isImmediate) {
		[self speak: text];		
	}
	
	lastText = [text copy];
	
	text = [[NSMutableString alloc] init];
	[self resetMoves];
}

- (void) zoomInterpreterRestart {
	[self zoomWaitingForInput];
}

#pragma mark - Glk automation


// Notifications about events that have occured in the view (when using this automation object for output)

- (void) receivedCharacters: (NSString*) characters					// Text has arrived at the specified text buffer window (from the game)
					 window: (__unused int) windowNumber
				   fromView: (__unused GlkView*) view {
	[text appendString: @"\n\n"];
	[text appendString: characters];
}

- (void) userTyped: (NSString*) userInput							// The user has typed the specified string into the specified window (which is any window that is waiting for input)
			window: (__unused int) windowNumber
		 lineInput: (__unused BOOL) isLineInput
		  fromView: (__unused GlkView*) view {
	[text appendString: @"\n\n"];
	[text appendString: userInput];
	[text appendString: @"...\n"];
}

- (void) userClickedAtXPos: (__unused int) xpos
					  ypos: (__unused int) ypos
					window: (__unused int) windowNumber
				  fromView: (__unused GlkView*) view {
}

- (void) viewWaiting: (__unused GlkView*) view {
	[self zoomWaitingForInput];
}

@synthesize immediate=isImmediate;

- (void) speakLastText {
	if (lastText) {
		[self speak: lastText];
	} else {
		[self speak: @"No text is available for the last move"];
	}
}

- (void) speak: (NSString*) newText {
#ifndef UseCocoaSpeech
	// TODO: Better iterating through string
	NSMutableString* buffer = [NSMutableString string];
	int x;
	
#define WriteBuffer(x) [buffer appendFormat:@"%C", (unichar)(x)]
	
	BOOL whitespace = YES;
	BOOL newline = YES;
	BOOL punctuation = NO;
	
	for (x=0; x<[newText length]; x++) {
		unichar chr = [newText characterAtIndex: x];
		
		if (chr >= 127) {
			whitespace = newline = punctuation = NO;
			WriteBuffer(chr);
			continue;
		}
		
		if (chr != '\n' && chr != '\r' && (chr < 32 || chr >= 127)) chr = ' ';
		
		switch (chr) {
			case ' ':
				punctuation = NO;
				if (!whitespace) {
					whitespace = YES;
					WriteBuffer(' ');
				}
					break;
				
			case '\n':
			case '\r':
				if (!punctuation && !whitespace) {
					punctuation = YES;
					WriteBuffer('.');
				} else {
					punctuation = NO;
				}
				
				if (!newline) {
					whitespace = YES;
					newline = YES;
					WriteBuffer('\n');
				}
				break;
				
			case ',': case '.': case '?': case ';': case ':': case '!':
				if (!punctuation) {
					punctuation = YES;
					WriteBuffer(chr);
				}
				break;
				
			default:
				whitespace = newline = punctuation = NO;
				WriteBuffer(chr);
		}
	}
	
	SpeakCFString(channel, (__bridge CFStringRef _Nonnull)(buffer), NULL);
#else
	[synth startSpeakingString: newText];
#endif	
}

- (void) beQuiet {
#ifndef UseCocoaSpeech
	StopSpeech(channel);
#else
	[synth stopSpeaking];
#endif
}

@synthesize skein;

- (BOOL) speakBehind: (int) position {
	// Iterate up the skein until we get to the move we want
	ZoomSkeinItem* itemToSpeak = [skein activeItem];
	
	int count = 0;
	while (itemToSpeak != nil && count < position) {
		itemToSpeak = [itemToSpeak parent];
		count++;
	}
	
	if (itemToSpeak == nil) {
		// Mention if we've reached the end
		[self speak: @"There are no previous moves"];
		
		return NO;
	} else {
		NSMutableString* toSpeak = [NSMutableString string];
		
		if (position <= 0) {
			[toSpeak appendFormat: @"Most recent move:\n"];
		} else {
			[toSpeak appendFormat: @"%i moves ago:\n", position+1];			
		}
		
		if (position <= 0 && lastText) {
			[toSpeak appendString: lastText];
		} else {
			[toSpeak appendFormat: @"%@.\n%@", [itemToSpeak command], [itemToSpeak result]];			
		}
		[self speak: toSpeak];
		
		return YES;
	}
}

- (void) speakPreviousMove {
	if ([self speakBehind: movesBehind]) {
		movesBehind++;
	}
}

- (void) speakNextMove {
	if (movesBehind > 1) {
		movesBehind--;
		[self speakBehind: movesBehind-1];
	} else {
		[self speak: @"No further moves"];
	}
}

- (void) resetMoves {
	movesBehind = 0;
}

// Using this automation object for input

- (void) viewIsWaitingForInput: (__unused GlkView*) view {
	[self zoomWaitingForInput];
}

@end
