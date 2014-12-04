//
//  ZoomTextToSpeech.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 21/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomView/ZoomSkein.h>
#import <GlkView/GlkAutomation.h>

//
// An output source that performs text-to-speech functions
//
@interface ZoomTextToSpeech : NSObject<GlkAutomation> {
	NSMutableString* lastText;											// The last text that was spoken
	NSMutableString* text;												// The text that will be spoken once the current command finishes
	NSSpeechSynthesizer* synth;											// The cocoa speech synthesizer to use (if in Cocoa mode, which we don't use as it ignores speech preferences)
	BOOL isImmediate;													// Whether or not this speaks immediately or not

	ZoomSkein* skein;													// The skein to use when speaking moves
	int movesBehind;													// The number of moves behind to speak
}

- (void) setImmediate: (BOOL) immediateSpeech;							// YES if this should speak immediately, no if only on request
- (void) speakLastText;													// Repeats the last text spoken by this object
- (void) speak: (NSString*) text;										// Speaks the specified text
- (void) beQuiet;														// Stops speaking

- (void) setSkein: (ZoomSkein*) skein;									// Sets the skein this object should use
- (void) speakPreviousMove;												// Speaks one move behind (if a skein is set)
- (void) speakNextMove;													// Speaks one move ahead
- (void) resetMoves;													// Resets the number of moves for the previous/next move

@end
