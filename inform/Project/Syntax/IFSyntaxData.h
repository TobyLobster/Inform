//
//  IFSyntaxData.h
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import <Cocoa/Cocoa.h>
#import "IFSyntaxTypes.h"

// *******************************************************************************************
//
// Data about a restricted region of text storage
//
@interface IFSyntaxRestricted : NSObject {
    NSTextView*              _textView;
    NSTextStorage*           _restrictedTextStorage;
    NSRange                  _restrictedRange;
}

-(id) initWithTextView: (NSTextView*)view
                 range: (NSRange) range;

@property (retain) NSTextView*      textView;
@property (retain) NSTextStorage*   restrictedTextStorage;
@property          NSRange          restrictedRange;

@end


// *******************************************************************************************
//
// Records useful syntax information about an NSTextStorage object
//
@interface IFSyntaxData : NSObject<NSTextStorageDelegate> {
    NSTextStorage*                  _textStorage;
    NSString*                       _name;
    IFHighlightType                 _type;
    NSUndoManager*                  _undoManager;
    bool                            _isHighlighting;
    
    // Restricted storage
    NSMutableArray*          _restrictions;

    //
	// Syntax state - Line and character information
    //
	int				nLines;				// Number of lines
	unsigned*		lineStarts;			// Start positions of each line
	NSMutableArray* lineStates;			// Syntax stack at the start of lines

	IFSyntaxStyle*  charStyles;			// Syntax state for each character
	NSMutableArray* lineStyles;			// NSParagraphStyles for each line

    //
	// Syntax state - current highlighter state
    //
	NSMutableArray*   syntaxStack;		// Current syntax stack
	int				  syntaxPos;		// Current highlighter position
	IFSyntaxState     syntaxState;		// Active state
	IFHighlighterMode syntaxMode;		// 'Mode' - possible extra state from the highlighter

    //
	// The highlighter
    //
	id<IFSyntaxHighlighter,NSObject> highlighter;

    //
	// Paragraph styles
    //
	NSMutableArray*	tabStops;               // Tab stop array
	NSMutableArray*	paragraphStyles;        // Maps number of tabs at the start of a line to the appropriate paragraph style
	BOOL			computingElasticTabs;	// YES if we're currently computing elastic tab sizes

    //
	// 'Intelligence'
    //
	id<IFSyntaxIntelligence,NSObject> intelSource;
	IFIntelFile* intelData;				// 'Intelligence' data

	NSRange editingRange;				// Used while rewriting
}

@property (retain) NSTextStorage*           textStorage;
@property (retain) NSString*                name;
@property IFHighlightType                   type;
@property (retain) NSUndoManager*           undoManager;
@property bool                              isHighlighting;

// Initialisation
-(id) initWithStorage: (NSTextStorage*) aStorage
                 name: (NSString*) aName
                 type: (IFHighlightType) aType
         intelligence: (id<IFSyntaxIntelligence,NSObject>) intelligence
          undoManager: (NSUndoManager*) aUndoManager;
-(void) dealloc;

// Syntax Highlighting
- (void) highlightAllForceUpdateTabs: (bool) forceUpdateTabs;

// Communication from the highlighter
- (void) pushState;												// Pushes the current state onto the stack
- (IFSyntaxState) popState;										// Pops a state from the stack (which is returned)

- (void) backtrackWithStyle: (IFSyntaxStyle) newStyle			// Overwrites the styles backwards from the current position
					 length: (int) backtrackLength;

- (void) setHighlighterMode: (IFHighlighterMode) newMode;		// Allows the highlighter to run in different 'modes' (basically, extends the state data to 64 bits)
- (IFHighlighterMode) highlighterMode;							// Retrieves the current highlighter mode
- (BOOL) preceededByKeyword: (NSString*) keyword				// If the given keyword occurs offset characters behind the current position, returns YES (ie, if the given keyword occurs and ends offset characters previously)
					 offset: (int) offset;

- (void) preferencesChanged: (NSNotification*) not;				// Forces a rehighlight (to take account of new preferences)

// Elastic Tabs
- (NSRange) rangeOfElasticRegionAtIndex: (int) charIndex;		// Given a character index, works out the character range that elastic tabs should be applied to. Uses NSNotFound if elastic tabs shouldn't be applied to this range
- (NSArray*) elasticTabsInRegion: (NSRange) region;				// Given a region, returns the set of tab stops to use for elastic tabs
- (NSDictionary*) paragraphStyleForTabStops: (int) numberOfTabstops;	// Gets a paragraph style for the given number of tab stops

// Gathering/retrieving intelligence data
- (void) setIntelligence: (id<IFSyntaxIntelligence,NSObject>) intel;		// Sets the intelligence object for this highlighter
- (id<IFSyntaxIntelligence>) intelligence;						// Retrieves the current intelligence object
- (IFIntelFile*) intelligenceData;								// Retrieves the intel data for the current intelligence object

// Intelligence callbacks (rewriting lines)
- (int) editingLineNumber;										// (To be called from rewriteInput) the number of the line being rewritten
- (int) numberOfTabStopsForLine: (int) lineNumber;				// (To be called from rewriteInput) the number of tab stops on the given line
- (NSString*) textForLine: (int) lineNumber;					// (To be called from rewriteInput) the text for a specific line number (which must be lower than the current line number)

- (IFSyntaxStyle) styleAtStartOfLine: (int) lineNumber;			// (To be called from rewriteInput) the syntax highlighting style at the start of a specific line
- (IFSyntaxStyle) styleAtEndOfLine: (int) lineNumber;			// (To be called from rewriteInput) the style at the end of a specific line

- (unichar) characterAtEndOfLine: (int) lineNumber;				// (To be called from rewriteInput) the character at the end of a specific line

- (void) callbackForEditing: (SEL) selector						// (To be called from rewriteInput) callback allows editing outside the current line
				  withValue: (id) parameter;
- (void) replaceLine: (int) lineNumber							// (To be called from the callbackForEditing) replaces a line with another line
			withLine: (NSString*) newLine;                      // DANGEROUS! May change styles, invoke the highlighter, etc

//
// Restricted text storage
//
-(void) restrictToRange: (NSRange) range
            forTextView: (NSTextView*) view;
-(void) removeRestrictionForTextView: (NSTextView*) view;
-(BOOL) isRestrictedForTextView:(NSTextView*) view;
-(NSRange) restrictedRangeForTextView:(NSTextView*) view;
-(NSTextStorage*) restrictedTextStorageForTextView:(NSTextView*) view;

@end

