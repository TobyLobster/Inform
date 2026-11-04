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

@protocol IFSourceNavigation <NSObject>

#pragma mark Navigating through sections
/// User clicked on the top tear
- (void) sourceFileShowPreviousSection: (id) sender;
/// User clicked on the bottom tear
- (void) sourceFileShowNextSection: (id) sender;

@end

///
/// The 'source' page
///
@interface IFSourcePage : IFPage<NSTextViewDelegate,NSTextStorageDelegate,IFSourceNavigation, IFHeaderPageDelegate>

#pragma mark - Source pane controls
/// Informs this pane that it's time to prepare to save the document
- (void) prepareToSave;

/// Gets the range of characters that correspond to a specific line number
- (NSRange) findLine: (NSUInteger) line;
/// Scrolls the source view so that the given line/character to be visible
- (void) moveToLine: (NSInteger) line
		  character: (int) chr;
/// Scrolls the source view so that the given line to be visible
- (void) moveToLine: (NSInteger) line;
/// Scrolls the source view so that the given character index is visible
- (void) moveToLocation: (NSInteger) location;
/// Selects a range of characters in the source view
- (void) selectRange: (NSRange) range;
/// Indicates a range of characters in the source view
- (void) indicateRange: (NSRange) rangeToHighlight;

/// Pastes in the given code at the current insertion position (replacing any selected code and updating the undo manager)
- (void) pasteSourceCode: (NSString*) sourceCode;

/// Shows the source file with the given filename in the view
- (void) showSourceFile: (NSString*) file;
/// Returns the unprocessed name of the currently open file (currentFile is usually more appropriate than this)
@property (atomic, readonly, copy) NSString *openSourceFilepath;
/// Returns the currently displayed filename
@property (atomic, readonly, copy) NSString *currentFile;
/// Returns the line the cursor is currently on
@property (atomic, readonly) int currentLine;

/// Shows an indicator for the specified line number
- (void) indicateLine: (int) line;
/// Updates the temporary highlights (which display breakpoints, etc)
- (void) updateHighlightedLines;

/// The active IntelFile object for the current view (ie, the object that's dealing with auto-tabs, the dynamic index, etc)
@property (atomic, readonly, strong) IFIntelFile *currentIntelligence;

/// Sets check-as-you-type on or off
- (void) setSpellChecking: (BOOL) checkSpelling;

#pragma mark - The header page
- (IBAction) showHeaderPage: (id) sender;
- (IBAction) hideHeaderPage: (id) sender;
- (IBAction) toggleHeaderPage: (id) sender;

/// Shows the section containing the beginning of the selection
- (IBAction) showCurrentSectionOnly: (id) sender;
/// Decreases the number of headings displayed around the cursor
- (IBAction) showFewerHeadings: (id) sender;
/// Increases the number of headings displayed around the cursor
- (IBAction) showMoreHeadings: (id) sender;
/// Displays the entire source code, keeping the cursor in the same position
- (IBAction) showEntireSource: (id) sender;

- (instancetype) initWithProjectController: (IFProjectController*) controller NS_DESIGNATED_INITIALIZER;

@end
