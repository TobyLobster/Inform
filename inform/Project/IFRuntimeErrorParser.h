//
//  IFRuntimeErrorParser.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 10/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomView/ZoomView.h>
#import <GlkView/GlkView.h>

///
/// Natural Inform (or Inform 7 as it's now more officially known) can produce runtime errors.
/// This class implements a Zoom output receiver that parses these out and reports them to a
/// delegate method.
///
@interface IFRuntimeErrorParser : NSObject<GlkAutomation> {
	id delegate;								// The delegate
	NSMutableString* accumulator;				// The character accumulator
}

- (void) outputText: (NSString*) outputText;	// Called by Zoom when output is generated
- (void) setDelegate: (id) delegate;			// Sets the delegate for this object. The delegate is not retained.

@end

@interface NSObject(IFRuntimeErrorParserDelegate)

- (void) runtimeError: (NSString*) error;		// Called when a runtime problem occurs in the output

@end
