//
//  IFNaturalHighlighter.m
//  Inform
//
//  Created by Andrew Hunter on 18/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFNaturalHighlighter.h"
#import "IFInform6Highlighter.h"
#import "IFProjectPane.h"
#import "IFPreferences.h"
#import "IFSyntaxData.h"
#import "IFSyntaxStyles.h"

@implementation IFNaturalHighlighter {
    /// Syntax data that we're using
    IFSyntaxData* activeData;

    /// Highlighter for portions of the file that are Inform 6 code
    IFInform6Highlighter* inform6Highlighter;
}

#pragma mark - Initialisation

- (instancetype) init {
	self = [super init];
	
	if (self) {
		inform6Highlighter = [[IFInform6Highlighter alloc] init];
	}
	
	return self;
}


#pragma mark - Notifying of the highlighter currently in use

- (void) setSyntaxData: (IFSyntaxData*) aData {
	activeData = aData;
	
    [inform6Highlighter setSyntaxData: aData];
}

#pragma mark - The highlighter itself

- (IFSyntaxState) stateForCharacter: (unichar) chr
						 afterState: (IFSyntaxState) lastState {
	switch (activeData.highlighterMode) {
		case IFNaturalModeStandard:
			// Natural Inform mode
			switch (lastState) {
				case IFNaturalStateMaybeInform6:
					if (chr == '-') {
						// Switch to Inform 6 mode
						[activeData pushState];
						activeData.highlighterMode = IFNaturalModeInform6;
						
						if ([activeData preceededByKeyword: @"Include"
													   offset: 1]) {
							// Is top-level Inform 6
							return IFSyntaxStateDefault;
						} else {
							// Is as if preceeded by '[T;'
							IFSyntaxState newState =  [inform6Highlighter stateForCharacter: '['
																				 afterState: IFSyntaxStateDefault];
							newState = [inform6Highlighter stateForCharacter: 'T'
																  afterState: newState];
							newState = [inform6Highlighter stateForCharacter: ';'
																  afterState: newState];
							return newState;
						}
					}
				case IFNaturalStateBlankLine:
					if (chr == ' ' || chr == '\n' || chr == '\t' || chr == '\r')
						return IFNaturalStateBlankLine;
					// ObRAIF: here is why fall-through cases are a *good* thing
					// (Of course, first time I tried this, I got these conditions the wrong way round... Mmm, bug)
				case IFNaturalStateSpace:
					if ((chr == '"') || (chr == 0x201C) || (chr == 0x201D))
						return IFNaturalStateQuote;
				case IFNaturalStateText:
					// Just plain ole text
					if (chr == '[') {
						[activeData pushState];
						return IFNaturalStateComment;
					}
					if (chr == '\n' || chr == '\r')
						return IFNaturalStateBlankLine;
						
					if (chr == '(')
						return IFNaturalStateMaybeInform6;
					if (chr == ' ' || chr == '\t' || chr == '.' || chr == ')' || chr == '}' || chr == ';'
						|| chr == ':' || chr == ',' || chr == '?' || chr == '!' || chr == '{')
						return IFNaturalStateSpace;
					return IFNaturalStateText;
					
				case IFNaturalStateComment:
					if (chr == '[') {
						[activeData pushState];
						return IFNaturalStateComment;
					}
					if (chr == ']') {
						return activeData.popState;
					}
					return IFNaturalStateComment;
				
				case IFNaturalStateSubstitution:
					if (chr == ']')
						return IFNaturalStateQuote;
				case IFNaturalStateQuote:
					if ((chr == '"') || (chr == 0x201C) || (chr == 0x201D))
						return IFNaturalStateText;
					if (chr == '[')
						return IFNaturalStateSubstitution;
					return lastState;

				case IFNaturalStateHeading:
					if (chr == '\n' || chr == '\r')
						return IFNaturalStateBlankLine;
					return IFNaturalStateHeading;
			}
            // Unknown state
            return IFNaturalStateText;
			
		// Various Inform 6 modes
		case IFNaturalModeInform6MightEnd:
			if (chr == ')') {
				// Switch back to standard mode
				[activeData popState];
				return IFNaturalStateText;
			}
			
			// Switch back to Inform 6 mode
			activeData.highlighterMode = IFNaturalModeInform6;
			
		case IFNaturalModeInform6:
			if (chr == '-') {
				// Next character might break us out of Inform 6 mode
				activeData.highlighterMode = IFNaturalModeInform6MightEnd;
			}
			
			// Run the Inform 6 highlighter
			return [inform6Highlighter stateForCharacter: chr
											  afterState: lastState];
	}

	return IFNaturalStateText;
}

- (IFSyntaxStyle) styleForCharacter: (unichar) chr
						  nextState: (IFSyntaxState) nextState
						  lastState: (IFSyntaxState) lastState {
	switch (activeData.highlighterMode) {
		// Natural Inform styles
		case IFNaturalModeStandard:
			// Some states override the next state
            if(( lastState == IFNaturalStateQuote ) &&
               ( nextState != IFNaturalStateSubstitution )) {
                return IFSyntaxGameText;
            }
            if( lastState == IFNaturalStateComment ) {
                return IFSyntaxComment;
            }
            if( lastState == IFNaturalStateSubstitution ) {
                return IFSyntaxSubstitution;
            }
            
			switch (nextState) {
                case IFNaturalStateComment:
					return IFSyntaxComment;
					
				case IFNaturalStateQuote:
					return IFSyntaxGameText;
					
				case IFNaturalStateSubstitution:
					return IFSyntaxSubstitution;
					
				case IFNaturalStateHeading:
					return IFSyntaxHeading;

                case IFNaturalStateSpace:
                case IFNaturalStateText:
				case IFNaturalStateBlankLine:
                case IFNaturalStateMaybeInform6:
                    return IFSyntaxNaturalInform;
			}
            return IFSyntaxNaturalInform;

		// Inform 6 styles
		case IFNaturalModeInform6MightEnd:
		case IFNaturalModeInform6:
			return [inform6Highlighter styleForCharacter: chr
											   nextState: nextState
											   lastState: lastState] + 0x20;
	}

	return IFSyntaxNone;
}

static BOOL IsInform6Style(IFSyntaxStyle style) {
	if (style >= 0x20 && style <= 0x40)
		return YES;
	else
		return NO;
}

- (void) rehintLine: (NSString*) line
			 styles: (IFSyntaxStyles*) styles
	   initialState: (IFSyntaxState) initialState {
    NSString* thisLine = [line.lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	// This line might be a header line
	BOOL isHeader = NO;
    BOOL isInAppropriateStateForHeader = (initialState == IFNaturalStateBlankLine) || (initialState == IFSyntaxStateDefault);

    if (styles.numCharStyles == 0) {
        return;
    }

    if (isInAppropriateStateForHeader && !IsInform6Style([styles read:0])) {
        if ([thisLine hasPrefix: @"---- documentation ----"]) isHeader = YES;
		if ([thisLine hasPrefix: @"volume "])   isHeader = YES;
        if ([thisLine hasPrefix: @"volume: "])  isHeader = YES;
		if ([thisLine hasPrefix: @"book "])     isHeader = YES;
        if ([thisLine hasPrefix: @"book: "])    isHeader = YES;
		if ([thisLine hasPrefix: @"part "])     isHeader = YES;
        if ([thisLine hasPrefix: @"part: "])    isHeader = YES;
		if ([thisLine hasPrefix: @"chapter "])  isHeader = YES;
        if ([thisLine hasPrefix: @"chapter: "]) isHeader = YES;
		if ([thisLine hasPrefix: @"section "])  isHeader = YES;
        if ([thisLine hasPrefix: @"section: "]) isHeader = YES;
        if ([thisLine hasPrefix: @"example: "]) isHeader = YES;
	}

	if (isHeader) {
		int x;
		for (x=0; x<line.length; x++) {
            [styles write:x value:IFSyntaxHeading];
		}
	}
	
	// This line might have some Inform 6 highlighting to do
    IFSyntaxStyles* i6Styles = [[IFSyntaxStyles alloc] init];
	int x;
	for (x=0; x<line.length; x++) {
        if (IsInform6Style([styles read:x])) {
			// Found an Inform 6 region
			NSRange thisRegion;
			
			thisRegion.location = x;
			thisRegion.length = 0;
			
			// Convert to standard style, work out how long the region is
            for (;x<line.length && IsInform6Style([styles read:x]);x++) {
				thisRegion.length++;
                [styles write:x value: [styles read:x]- 0x20];
			}
			
			// Get the Inform 6 highlighter to rehint this section
            i6Styles.styles = styles.styles + thisRegion.location;
            i6Styles.numCharStyles = styles.numCharStyles-thisRegion.location;
			[inform6Highlighter rehintLine: [line substringWithRange: thisRegion] 
									styles: i6Styles
							  initialState: IFSyntaxStateDefault];
		}
	}
}

#pragma mark - Styles

- (NSDictionary*) attributesForStyle: (IFSyntaxStyle) style {
	return [IFProjectPane attributeForStyle: style];
}

- (CGFloat) tabStopWidth {
	return [IFPreferences sharedPreferences].tabWidth;
}

@end
