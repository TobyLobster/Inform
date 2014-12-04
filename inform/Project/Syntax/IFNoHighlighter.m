//
//  IFNoHighlighter.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 18/10/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//

#import "IFNoHighlighter.h"
#import "IFProjectPane.h"
#import "IFPreferences.h"
#import "IFSyntaxData.h"

@implementation IFNoHighlighter

// = Initialisation =

- (id) init {
	self = [super init];
	
	if (self) {
	}
	
	return self;
}

- (void) dealloc {
	[activeData release];
	
	[super dealloc];
}

// = Notifying of the highlighter currently in use =

- (void) setSyntaxData: (IFSyntaxData*) aData {
	[activeData release];
	activeData = [aData retain];
}

// = The highlighter itself =

- (IFSyntaxState) stateForCharacter: (unichar) chr
						 afterState: (IFSyntaxState) lastState {
	return IFSyntaxStateDefault;
}

- (IFSyntaxStyle) styleForCharacter: (unichar) chr
						  nextState: (IFSyntaxState) nextState
						  lastState: (IFSyntaxState) lastState {
	return IFSyntaxNone;
}

- (void) rehintLine: (NSString*) line
			 styles: (IFSyntaxStyle*) styles
	   initialState: (IFSyntaxState) initialState {
}

// = Styles =

- (NSDictionary*) attributesForStyle: (IFSyntaxStyle) style {
	return [IFProjectPane attributeForStyle: style];
}

- (float) tabStopWidth {
	return [[IFPreferences sharedPreferences] tabWidth];
}

@end
