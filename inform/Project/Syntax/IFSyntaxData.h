//
//  IFSyntaxData.h
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import <Cocoa/Cocoa.h>
#import "IFSyntaxTypes.h"

// *******************************************************************************************
///
/// Data about a restricted region of text storage
///
@interface IFSyntaxRestricted : NSObject

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithTextView: (NSTextView*)view
                            range: (NSRange) range NS_DESIGNATED_INITIALIZER;

@property (atomic, strong) NSTextView*      textView;
@property (atomic, strong) NSTextStorage*   restrictedTextStorage;
@property (atomic)         NSRange          restrictedRange;

@end


// *******************************************************************************************
///
/// Class holds the model for a text file currently being shown in a project. Each object owns
/// the full text of a file, and up to two restricted versions (for the left/right hand panes of
/// the project).
///
/// Records useful syntax information about an NSTextStorage object
///
@interface IFSyntaxData : NSObject<NSTextStorageDelegate>

@property (atomic, strong)  NSTextStorage*  textStorage;
@property (atomic, strong)  NSString*       name;
@property (atomic)          IFHighlightType type;
@property (atomic, strong)  NSUndoManager*  undoManager;
@property (atomic)          bool            isHighlighting;

// Initialisation
- (instancetype)init NS_UNAVAILABLE;

-(instancetype) initWithStorage: (NSTextStorage*) aStorage
                 name: (NSString*) aName
                 type: (IFHighlightType) aType
         intelligence: (id<IFSyntaxIntelligence>) intelligence
          undoManager: (NSUndoManager*) aUndoManager NS_DESIGNATED_INITIALIZER;

// Syntax Highlighting
- (void) highlightAllForceUpdateTabs: (bool) forceUpdateTabs;

// Communication from the highlighter
/// Pushes the current state onto the stack
- (void) pushState;
/// Pops a state from the stack (which is returned)
-(IFSyntaxState) popState;

/// Overwrites the styles backwards from the current position
- (void) backtrackWithStyle: (IFSyntaxStyle) newStyle
					 length: (int) backtrackLength;
		
/// Allows the highlighter to run in different 'modes' (basically, extends the state data to 64 bits)
/// Retrieves the current highlighter mode
@property (atomic) IFHighlighterMode highlighterMode;
/// If the given keyword occurs offset characters behind the current position, returns \c YES (ie, if the given keyword occurs and ends offset characters previously)
- (BOOL) preceededByKeyword: (NSString*) keyword
					 offset: (int) offset;

/// Forces a rehighlight (to take account of new preferences)
- (void) preferencesChanged: (NSNotification*) not;

// Elastic Tabs
/// Given a character index, works out the character range that elastic tabs should be applied to. Uses \c NSNotFound if elastic tabs shouldn't be applied to this range
- (NSRange) rangeOfElasticRegionAtIndex: (NSUInteger) charIndex;
/// Given a region, returns the set of tab stops to use for elastic tabs
- (NSArray*) elasticTabsInRegion: (NSRange) region;
/// Gets a paragraph style for the given number of tab stops
- (NSDictionary*) paragraphStyleForTabStops: (int) numberOfTabstops;

// Gathering/retrieving intelligence data
/// Sets the intelligence object for this highlighter
- (void) setIntelligence: (id<IFSyntaxIntelligence>) intel;
/// Retrieves the current intelligence object
- (id<IFSyntaxIntelligence>) intelligence;
@property (nonatomic, strong) id<IFSyntaxIntelligence> intelligence;
/// Retrieves the intel data for the current intelligence object
@property (atomic, readonly, strong) IFIntelFile *intelligenceData;

// Intelligence callbacks (rewriting lines)
/// (To be called from rewriteInput) the number of the line being rewritten
@property (atomic, readonly) int editingLineNumber;
/// (To be called from rewriteInput) the number of tab stops on the given line
- (int) numberOfTabStopsForLine: (int) lineNumber;
/// (To be called from rewriteInput) the text for a specific line number (which must be lower than the current line number)
- (NSString*) textForLine: (int) lineNumber;

/// (To be called from rewriteInput) the syntax highlighting style at the start of a specific line
- (IFSyntaxStyle) styleAtStartOfLine: (int) lineNumber;
/// (To be called from rewriteInput) the style at the end of a specific line
- (IFSyntaxStyle) styleAtEndOfLine: (int) lineNumber;

/// (To be called from rewriteInput) the character at the end of a specific line
- (unichar) characterAtEndOfLine: (int) lineNumber;

/// (To be called from rewriteInput) callback allows editing outside the current line
- (void) callbackForEditing: (SEL) selector
				  withValue: (id) parameter;
/// (To be called from the callbackForEditing) replaces a line with another line
///
/// DANGEROUS! May change styles, invoke the highlighter, etc
- (void) replaceLine: (int) lineNumber
			withLine: (NSString*) newLine;

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

