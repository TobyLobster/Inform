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

NS_ASSUME_NONNULL_BEGIN

@class IFIntelFile;

@protocol IFSourceNavigation <NSObject>

#pragma mark Navigating through sections
/// User clicked on the top tear
- (void) sourceFileShowPreviousSection: (nullable id) sender;
/// User clicked on the bottom tear
- (void) sourceFileShowNextSection: (nullable id) sender;

@end

///
/// The 'source' page
///
@interface IFSourcePage : IFPage<NSTextViewDelegate,IFSourceNavigation, IFHeaderPageDelegate, NSMenuItemValidation>

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
/// Selects a range of characters in the source view
- (void) selectRange: (NSRange) range;
/// Indicates a range of characters in the source view
- (void) indicateRange: (NSRange) rangeToHighlight;

/// Pastes in the given code at the current insertion position (replacing any selected code and updating the undo manager)
- (void) pasteSourceCode: (NSString*) sourceCode;

/// Shows the source file with the given filename in the view
- (void) showSourceFile: (nullable NSString*) file;
/// Returns the unprocessed name of the currently open file (currentFile is usually more appropriate than this)
@property (atomic, readonly, copy, nullable) NSString *openSourceFilepath;
/// Returns the currently displayed filename
@property (atomic, readonly, copy, nullable) NSString *currentFile;

/// Shows an indicator for the specified line number
- (void) indicateLine: (int) line;
/// Updates the temporary highlights (which display breakpoints, etc)
- (void) updateHighlightedLines;

/// The active IntelFile object for the current view (ie, the object that's dealing with auto-tabs, the dynamic index, etc)
@property (atomic, readonly, strong, nullable) IFIntelFile *currentIntelligence;

/// Sets check-as-you-type on or off
- (void) setSpellChecking: (BOOL) checkSpelling;

#pragma mark - The header page
- (IBAction) showHeaderPage: (nullable id) sender;
- (IBAction) toggleHeaderPage: (nullable id) sender;

/// Shows the section containing the beginning of the selection
- (IBAction) showCurrentSectionOnly: (nullable id) sender;
/// Decreases the number of headings displayed around the cursor
- (IBAction) showFewerHeadings: (nullable id) sender;
/// Increases the number of headings displayed around the cursor
- (IBAction) showMoreHeadings: (nullable id) sender;
/// Displays the entire source code, keeping the cursor in the same position
- (IBAction) showEntireSource: (nullable id) sender;

- (instancetype) initWithProjectController: (IFProjectController*) controller NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
