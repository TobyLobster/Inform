//
//  ZoomTextToSpeech.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 21/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomView/ZoomViewProtocols.h>
#import <ZoomView/ZoomSkein.h>
#import <GlkView/GlkAutomation.h>

//!
//! An output source that performs text-to-speech functions
//!
@interface ZoomTextToSpeech : NSObject<GlkAutomation, ZoomViewOutputReceiver> {
	//! The last text that was spoken
	NSMutableString* lastText;
	//! The text that will be spoken once the current command finishes
	NSMutableString* text;
	//! The cocoa speech synthesizer to use (if in Cocoa mode, which we don't use as it ignores speech preferences)
	NSSpeechSynthesizer* synth;
	//! Whether or not this speaks immediately or not
	BOOL isImmediate;

	//! The skein to use when speaking moves
	ZoomSkein* skein;
	//! The number of moves behind to speak
	int movesBehind;
}

//! \c YES if this should speak immediately, \c NO if only on request
@property (getter=isImmediate) BOOL immediate;
//! Repeats the last text spoken by this object
- (void) speakLastText;
//! Speaks the specified text
- (void) speak: (NSString*) text;
//! Stops speaking
- (void) beQuiet;

//! Sets the skein this object should use
@property (strong) ZoomSkein *skein;
//! Speaks one move behind (if a skein is set)
- (void) speakPreviousMove;
//! Speaks one move ahead
- (void) speakNextMove;
//! Resets the number of moves for the previous/next move
- (void) resetMoves;

@end
