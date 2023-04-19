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
@class IFSyntaxStyles;

//
// Predefined states
//

typedef unsigned int  IFHighlighterMode;
typedef unsigned int  IFSyntaxState;

NS_ENUM(IFSyntaxState) {
	IFSyntaxStateDefault = 0,
  	IFSyntaxStateNotHighlighted = 0xffffffff
};

/// Syntax styles
typedef NS_OPTIONS(unsigned char, IFSyntaxStyle) {
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
    /// Heading style
    IFSyntaxHeading = 0x80,
    /// 'No highlighting' style - lets user defined styles show through
	IFSyntaxPlain,
    /// Text that appears in the game
	IFSyntaxGameText,
    /// Substitution instructions
	IFSyntaxSubstitution,
    /// Natural inform standard text
	IFSyntaxNaturalInform,
    /// The title of a Natural Inform game
	IFSyntaxTitle,
	
    /// Used internally by the highlighter to indicate that the highlights are invalid for a particular range
	IFSyntaxStyleNotHighlighted = 0xf0,
    
    // Debugging syntax types
    IFSyntaxDebugHighlight = 0xa0
};

typedef NS_ENUM(unsigned int, IFHighlightType) {
    IFHighlightTypeNone,
    IFHighlightTypeInform6,
    IFHighlightTypeInform7,
};

@class IFSyntaxData;

///
/// Classes must implement this to create a new syntax highlighter
///
@protocol IFSyntaxHighlighter <NSObject>

#pragma mark - Notifying of the highlighter currently in use
/// Sets the syntax data that the highlighter is (currently) dealing with
- (void) setSyntaxData: (IFSyntaxData*) data;

// The highlighter itself
/// Retrieves the syntax state for a given character
- (IFSyntaxState) stateForCharacter: (unichar) chr
						 afterState: (IFSyntaxState) lastState;
/// Retrieves the style for a given character with the specified state transition
- (IFSyntaxStyle) styleForCharacter: (unichar) chr
						  nextState: (IFSyntaxState) nextState
						  lastState: (IFSyntaxState) lastState;
/// Opportunity to highlight keywords, etc missed by the first syntax highlighting pass. \c styles has
/// one entry per character in the line specified, and can be rewritten as required
- (void) rehintLine: (NSString*) line
			 styles: (IFSyntaxStyles*) styles
	   initialState: (IFSyntaxState) state;

#pragma mark - Styles
/// Retrieves the text attributes a specific style should use
- (NSDictionary<NSAttributedStringKey,id>*) attributesForStyle: (IFSyntaxStyle) style;
/// Retrieves the width of a tab stop
@property (readonly) CGFloat tabStopWidth;

@end


///
/// Classes must implement this to provide syntax intelligence (real-time indexing and autocomplete)
///
@protocol IFSyntaxIntelligence <NSObject>

#pragma mark - Notifying of the highlighter currently in use
/// Sets the syntax data that the intelligence object should use
- (void) setSyntaxData: (IFSyntaxData*) data;

// Gathering information (works like rehint)
/// Gathers intelligence data for the given line (with the given syntax highlighting styles, initial state and line number), and places the resulting data into the given IntelFile object
- (void) gatherIntelForLine: (NSString*) line
					 styles: (IFSyntaxStyles*) styles
			   initialState: (IFSyntaxState) state
				 lineNumber: (int) lineNumber
				   intoData: (IFIntelFile*) data;

// Autotyping (occurs when inserting single characters, and allows us to turn '\n' into '\n\t' for example
/// Opportunity to automatically insert data (for instance to implement auto-tabbing)
- (NSString*) rewriteInput: (NSString*) input;

@end


///
/// NSTextStorage subclasses can implement this to be notified of events on the main text storage object
///
@protocol IFDerivativeStorage <NSObject>

- (void) didBeginEditing: (NSTextStorage*) storage;
- (void) didEdit: (NSTextStorage*) storage
			mask: (unsigned int) mask
  changeInLength: (int) lengthChange
		   range: (NSRange) range;
- (void) didEndEditing: (NSTextStorage*) storage;

@end
