//
//  IFSourcePage.h
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFPage.h"
#import "IFHeaderPage.h"

@class IFIntelFile;

//
// The 'source' page
//
@protocol IFSourceNavigation <NSObject>

// Navigating through sections
- (void) sourceFileShowPreviousSection: (id) sender;			// User clicked on the top tear
- (void) sourceFileShowNextSection: (id) sender;				// User clicked on the bottom tear

@end

@interface IFSourcePage : IFPage<NSTextViewDelegate,NSTextStorageDelegate,IFSourceNavigation, IFHeaderPageDelegate>

// Source pane controls
- (void) prepareToSave;                                         // Informs this pane that it's time to prepare to save the document

- (NSRange) findLine: (NSUInteger) line;						// Gets the range of characters that correspond to a specific line number
- (void) moveToLine: (int) line									// Scrolls the source view so that the given line/character to be visible
		  character: (int) chr;
- (void) moveToLine: (int) line;								// Scrolls the source view so that the given line to be visible
- (void) moveToLocation: (int) location;						// Scrolls the source view so that the given character index is visible
- (void) selectRange: (NSRange) range;							// Selects a range of characters in the source view
- (void) indicateRange: (NSRange) rangeToHighlight;             // Indicates a range of characters in the source view

- (void) pasteSourceCode: (NSString*) sourceCode;				// Pastes in the given code at the current insertion position (replacing any selected code and updating the undo manager)

- (void) showSourceFile: (NSString*) file;						// Shows the source file with the given filename in the view
@property (atomic, readonly, copy) NSString *openSourceFilepath;	// Returns the unprocessed name of the currently open file (currentFile is usually more appropriate than this)
@property (atomic, readonly, copy) NSString *currentFile;			// Returns the currently displayed filename
@property (atomic, readonly) int currentLine;						// Returns the line the cursor is currently on

- (void) indicateLine: (int) line;								// Shows an indicator for the specified line number
- (void) updateHighlightedLines;								// Updates the temporary highlights (which display breakpoints, etc)

@property (atomic, readonly, strong) IFIntelFile *currentIntelligence;	// The active IntelFile object for the current view (ie, the object that's dealing with auto-tabs, the dynamic index, etc)

- (void) setSpellChecking: (BOOL) checkSpelling;				// Sets check-as-you-type on or off

// Breakpoints
- (IBAction) setBreakpoint: (id) sender;
- (IBAction) deleteBreakpoint: (id) sender;

// The header page
- (IBAction) showHeaderPage: (id) sender;
- (IBAction) hideHeaderPage: (id) sender;
- (IBAction) toggleHeaderPage: (id) sender;

- (IBAction) showCurrentSectionOnly: (id) sender;				// Shows the section containing the beginning of the selection
- (IBAction) showFewerHeadings: (id) sender;					// Decreases the number of headings displayed around the cursor
- (IBAction) showMoreHeadings: (id) sender;						// Increases the number of headings displayed around the cursor
- (IBAction) showEntireSource: (id) sender;						// Displays the entire source code, keeping the cursor in the same position

- (instancetype) initWithProjectController: (IFProjectController*) controller;

@end
