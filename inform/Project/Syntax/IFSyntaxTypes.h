//
//  IFSyntaxTypes.h
//  Inform
//
//  Created by Andrew Hunter on 17/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFIntelFile.h"

@class IFSyntaxData;

//
// Predefined states
//

enum {
	IFSyntaxStateDefault = 0,
  	IFSyntaxStateNotHighlighted = 0xffffffff
};

// Syntax styles
enum {
    // Basic syntax types
    IFSyntaxNone = 0,
    IFSyntaxString,
    IFSyntaxComment,
    IFSyntaxMonospace,
    
    // Inform 6 syntax types
    IFSyntaxDirective,
    IFSyntaxProperty,
    IFSyntaxFunction,
    IFSyntaxCode,
    IFSyntaxCodeAlpha,
    IFSyntaxAssembly,
    IFSyntaxEscapeCharacter,
	
	// Styles between 0x20-0x40 are the same as above but with a flag set
    
    // Natural inform syntax types
    IFSyntaxHeading = 0x80,				// Heading style
	IFSyntaxPlain,						// 'No highlighting' style - lets user defined styles show through
	IFSyntaxGameText,					// Text that appears in the game
	IFSyntaxSubstitution,				// Substitution instructions
	IFSyntaxNaturalInform,				// Natural inform standard text
	IFSyntaxTitle,						// The title of a Natural Inform game
	
	IFSyntaxStyleNotHighlighted = 0xf0,	// Used internally by the highlighter to indicate that the highlights are invalid for a particular range
    
    // Debugging syntax types
    IFSyntaxDebugHighlight = 0xa0
};

typedef enum {
    IFHighlightTypeNone,
    IFHighlightTypeInform6,
    IFHighlightTypeInform7,
} IFHighlightType;

typedef unsigned int  IFHighlighterMode;
typedef unsigned int  IFSyntaxState;
typedef unsigned char IFSyntaxStyle;

@class IFSyntaxData;

//
// Classes must implement this to create a new syntax highlighter
//
@protocol IFSyntaxHighlighter

// Notifying of the highlighter currently in use
- (void) setSyntaxData: (IFSyntaxData*) data;                       // Sets the syntax data that the highlighter is (currently) dealing with

// The highlighter itself
- (IFSyntaxState) stateForCharacter: (unichar) chr					// Retrieves the syntax state for a given character
						 afterState: (IFSyntaxState) lastState;
- (IFSyntaxStyle) styleForCharacter: (unichar) chr					// Retrieves the style for a given character with the specified state transition
						  nextState: (IFSyntaxState) nextState
						  lastState: (IFSyntaxState) lastState;
- (void) rehintLine: (NSString*) line								// Opportunity to highlight keywords, etc missed by the first syntax highlighting pass. styles has one entry per character in the line specified, and can be rewritten as required
			 styles: (IFSyntaxStyle*) styles
	   initialState: (IFSyntaxState) state;

// Styles
- (NSDictionary*) attributesForStyle: (IFSyntaxStyle) style;		// Retrieves the text attributes a specific style should use
- (float) tabStopWidth;												// Retrieves the width of a tab stop

@end


//
// Classes must implement this to provide syntax intelligence (real-time indexing and autocomplete)
//
@protocol IFSyntaxIntelligence

// Notifying of the highlighter currently in use
- (void) setSyntaxData: (IFSyntaxData*) data;               // Sets the syntax data that the intelligence object should use

// Gathering information (works like rehint)
- (void) gatherIntelForLine: (NSString*) line				// Gathers intelligence data for the given line (with the given syntax highlighting styles, initial state and line number), and places the resulting data into the given IntelFile object
					 styles: (IFSyntaxStyle*) styles
			   initialState: (IFSyntaxState) state
				 lineNumber: (int) lineNumber
				   intoData: (IFIntelFile*) data;

// Autotyping (occurs when inserting single characters, and allows us to turn '\n' into '\n\t' for example
- (NSString*) rewriteInput: (NSString*) input;				// Opportunity to automatically insert data (for instance to implement auto-tabbing)

@end


///
/// NSTextStorage subclasses can implement this to be notified of events on the main text storage object
///
@protocol IFDerivativeStorage

- (void) didBeginEditing: (NSTextStorage*) storage;
- (void) didEdit: (NSTextStorage*) storage
			mask: (unsigned int) mask
  changeInLength: (int) lengthChange
		   range: (NSRange) range;
- (void) didEndEditing: (NSTextStorage*) storage;

@end
