//
//  IFNoHighlighter.m
//  Inform
//
//  Created by Andrew Hunter on 18/10/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//

#import "IFNoHighlighter.h"
#import "IFProjectPane.h"
#import "IFPreferences.h"
#import "IFSyntaxData.h"

@implementation IFNoHighlighter {
    /// Syntax data that we're using
    IFSyntaxData* activeData;
}

#pragma mark - Initialisation

- (instancetype) init {
	self = [super init];
	
	if (self) {
	}
	
	return self;
}


#pragma mark - Notifying of the highlighter currently in use

- (void) setSyntaxData: (IFSyntaxData*) aData {
	activeData = aData;
}

#pragma mark - The highlighter itself

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
			 styles: (IFSyntaxStyles*) styles
	   initialState: (IFSyntaxState) initialState {
}

#pragma mark - Styles

- (NSDictionary*) attributesForStyle: (IFSyntaxStyle) style {
	return [IFProjectPane attributeForStyle: style];
}

- (CGFloat) tabStopWidth {
	return [IFPreferences sharedPreferences].tabWidth;
}

@end
