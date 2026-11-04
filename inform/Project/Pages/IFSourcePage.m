//
//  IFSourcePage.m
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFAppDelegate.h"
#import "IFSourcePage.h"
#import "IFProjectTypes.h"
#import "IFSyntaxManager.h"
#import "IFViewAnimator.h"
#import "IFPreferences.h"
#import "IFUtility.h"
#import "IFIntelSymbol.h"
#import "IFPageBarCell.h"
#import "IFHeaderController.h"
#import "IFProjectController.h"
#import "IFProject.h"
#import "IFHeaderPage.h"
#import "IFSourceFileView.h"
#import "IFColourTheme.h"
#import "Inform-Swift.h"

@interface IFSourcePage(IFSourcePagePrivate)

- (void) limitToRange: (NSRange) range
	preserveScrollPos: (BOOL)preserveScrollPos;
- (void) limitToSymbol: (IFIntelSymbol*) symbol
	preserveScrollPos: (BOOL)preserveScrollPos;
- (int) lineForCharacter: (NSUInteger) charNum
				 inStore: (NSString*) store;

@end

@implementation IFSourcePage {
    IBOutlet NSMenu*            contextMenu;

    NSTextStorage*              textStorage;					// The text storage object for this view
    NSLayoutManager*            layoutManager;
    NSTextContainer*            textContainer;
    IFSourceFileView*           textView;
    IFClickThroughScrollView*   scrollView;                     // Just allows mouseDown to come through

    NSString*                   openSourceFilepath;				// The name of the file that is open in this page

    // The header page control
    BOOL                        headerPageShown;
    IFPageBarCell*              sourcePageControl;				// The 'source page' toggle
    IFPageBarCell*              headerPageControl;				// The 'header page' toggle
    IFHeaderPage*               headerPage;						// The header page
}

#pragma mark - Initialisation

-(void) setBackgroundColour {
    IFProject* doc = (self.parent).document;

    if( doc.projectFileType == IFFileTypeInform7ExtensionProject ) {
        textView.backgroundColor = [IFPreferences sharedPreferences].extensionPaper.colour;
    }
    else {
        textView.backgroundColor = [IFPreferences sharedPreferences].sourcePaper.colour;
    }

    // Set the cursor colour
    if( [textView respondsToSelector: @selector(setInsertionPointColor:)] ) {
        IFColourTheme* theme = [[IFPreferences sharedPreferences] getCurrentTheme];
        if ((theme != nil) && ((theme.options).count > IFSHOptionMainText)) {
            textView.insertionPointColor = theme.options[IFSHOptionMainText].colour;
        }
    }
}

- (instancetype) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Source"
				projectController: controller];

	if (self) {
        // Notification
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(preferencesChanged:)
													 name: IFPreferencesEditingDidChangeNotification
												   object: [IFPreferences sharedPreferences]];
        
        //
        // Create textStorage and load the contents of our file into it.
        //
		IFProject* doc = (self.parent).document;
		textStorage = [doc storageForFile: doc.mainSourceFile];
        NSAssert(textStorage != nil, @"BUG: no main file!");
        if (textStorage == nil) {
			textStorage = [[NSTextStorage alloc] init];
        }

        //
        // Create a layoutManager, and connect it to our textStorage
        //
        layoutManager = [[NSLayoutManager alloc] init];
        [textStorage addLayoutManager: layoutManager];

        //
        // Create a text container, and add it to our layoutManager
        //
        textContainer = [[NSTextContainer alloc] initWithContainerSize: self.view.frame.size];
        [layoutManager addTextContainer:textContainer];
        
        //
        // Create scroll view
        //
        scrollView = [[IFClickThroughScrollView alloc] initWithFrame: (self.view).frame];
        scrollView.borderType = NSNoBorder;
        [scrollView setHasVerticalScroller: YES];
        [scrollView setHasHorizontalScroller: NO];
        scrollView.autoresizingMask = (NSUInteger) (NSViewWidthSizable | NSViewHeightSizable);
        NSSize contentSize = scrollView.contentSize;

        //
        // Set up the text view
        //
        textView = [[IFSourceFileView alloc] initWithFrame: NSMakeRect(0, 0, contentSize.width, contentSize.height)
                                             textContainer: textContainer];
        textView.minSize = NSMakeSize(0.0, contentSize.height);
        textView.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
        [textView setVerticallyResizable: YES];
        [textView setHorizontallyResizable: NO];
        textView.autoresizingMask = NSViewWidthSizable;
        textView.delegate = self;
        textView.menu = contextMenu;
        [textView setAllowsUndo:YES];
        [textView setRichText:NO];
        textView.enabledTextCheckingTypes = 0;

        textView.textContainer.containerSize = NSMakeSize(contentSize.width, FLT_MAX);
        [textView.textContainer setWidthTracksTextView: YES];
        textView.textContainerInset = NSMakeSize(3, 6);

        //
        // Attach the views together
        //
        scrollView.documentView = textView;
        [self.view addSubview: scrollView];

        //
        // Remember the filename
        //
		openSourceFilepath = doc.mainSourceFile;
        
        //
		// Monitor for file renaming events
        //
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(sourceFileRenamed:)
													 name: IFProjectSourceFileRenamedNotification
												   object: (self.parent).document];
		
        //
        // Sanity check - make sure Undo is set up correctly
        //
		NSAssert([textView undoManager] == [[self.parent document] undoManager], @"Oops: undo manager broken");

        //
		// Create the header page
        //
		headerPage = [[IFHeaderPage alloc] init];
		headerPage.delegate = self;

        //
		// Create the header/source page controls
        //
		headerPageControl = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"HeaderPage"
                                                                                    default: @"Headings"]];
		headerPageControl.target = self;
		headerPageControl.action = @selector(showHeaderPage:);
		headerPageControl.radioGroup = 1;

		sourcePageControl = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"SourcePage"
                                                                                    default: @"Source"]];
		sourcePageControl.radioGroup = 1;
		sourcePageControl.target = self;
		sourcePageControl.action = @selector(showSourcePage:);
		sourcePageControl.state = NSControlStateValueOn;
        
        [textView setSelectedRange: doc.initialSelectionRange];
        [self setBackgroundColour];
	}
	
	return self;
}

- (void) dealloc {
    // Main views and text classes
    [scrollView removeFromSuperview];

    // Remove all notifications
	[[NSNotificationCenter defaultCenter] removeObserver: self];

    // Header page
	[headerPage setDelegate: nil];
}

#pragma mark - Details about this view

- (NSString*) title {
	return [IFUtility localizedString: @"Source Page Title"
                              default: @"Source"];
}

@synthesize activeView;

#pragma mark - Text view delegate methods

- (NSUndoManager *)undoManagerForTextView:(NSTextView *)aTextView {
	// Always use the document undo manager
	return [(self.parent).document undoManager];
}

#pragma mark - Misc

- (void) pasteSourceCode: (NSString*) sourceCode {
	// Get the code that existed previously
	NSRange currentRange = [textView selectedRange];
	NSString* oldCode = [textStorage attributedSubstringFromRange: [textView selectedRange]].string;
	
	// Describe how to undo this paste - select new range, paste in the old code, select current range
	NSUndoManager* undo = textView.undoManager;
	
	[undo setActionName: [IFUtility localizedString: @"Paste Source Code"]];
	[undo beginUndoGrouping];
	
	[[undo prepareWithInvocationTarget: self] selectRange: currentRange];
	[[undo prepareWithInvocationTarget: self] pasteSourceCode: oldCode];
	[[undo prepareWithInvocationTarget: self] selectRange: NSMakeRange(currentRange.location, sourceCode.length)];
	
	[undo endUndoGrouping];
	
	// Perform the action
	[textView replaceCharactersInRange: currentRange
                            withString: sourceCode];
	[self selectRange: NSMakeRange(currentRange.location, sourceCode.length)];
}

- (void) sourceFileRenamed: (NSNotification*) not {
	// Called when a source file is renamed in the document. We need to do nothing, unless the source file
	// is the one we're displaying, in which we need to update the name of the source file we're displaying
	NSDictionary* dict = not.userInfo;
	NSString* oldName = dict[@"OldFilename"];
	NSString* newName = dict[@"NewFilename"];
	
	if ([oldName.lowercaseString isEqualToString: openSourceFilepath.lastPathComponent.lowercaseString]) {
		// The file being renamed is the one currently being displayed
		NSString* newSourceFile = [[(self.parent).document pathForSourceFile: newName] copy];
		
		if (newSourceFile) {
			openSourceFilepath = newSourceFile;
		}
	}
}

#pragma mark - Compiling

- (void) prepareToSave {
	[textView breakUndoCoalescing];
}

#pragma mark - Intelligence

- (IFIntelFile*) currentIntelligence {
	return [IFSyntaxManager intelligenceDataForStorage: textStorage];
}

#pragma mark - Indicating

- (void) indicateRange: (NSRange) range {
	// Look at restricted range if necessary
	if( [IFSyntaxManager isRestricted: textStorage
                          forTextView: textView] ) {
		NSRange restriction = [IFSyntaxManager restrictedRange: textStorage
                                                   forTextView: textView];
		if (range.location >= restriction.location &&
            range.location < (restriction.location + restriction.length)) {
			range.location -= restriction.location;
		} else {
			// Try moving the restriction range to something nearer the indicated line
			int line = [self lineForCharacter: range.location
									  inStore: textStorage.string];
			
			IFIntelFile* intel = self.currentIntelligence;
			IFIntelSymbol* symbol = [intel nearestSymbolToLine: line];
			
			if (symbol) {
				[self limitToSymbol: symbol
				  preserveScrollPos: NO];
			}
			
			// If the line is now available, then we can highlight the appropriate character
            restriction = [IFSyntaxManager restrictedRange: textStorage
                                               forTextView: textView];
			if (range.location >= restriction.location && range.location < (restriction.location + restriction.length)) {
				range.location -= restriction.location;
			} else {
				return;
			}
		}
	}

    [textView setSelectedRange: range];
    [textView scrollRangeToVisible: range];
    [textView showFindIndicatorForRange: range];
}

- (NSUInteger) indexOfLine: (NSUInteger) line
					inString: (NSString*) store {
    NSUInteger length = store.length;
	
    NSUInteger x = 0;
    NSUInteger linepos;
    NSUInteger lineno = 1;

    if (line > lineno)
	{
		for (x=0; x<length; x++) {
			unichar chr = [store characterAtIndex: x];
			
			if (chr == '\n' || chr == '\r') {
				unichar otherchar = chr == '\n'?'\r':'\n';
				
				lineno++;
				linepos = x + 1;
				
				// Deal with DOS line endings
				if (linepos < length && [store characterAtIndex: linepos] == otherchar) {
					x++; linepos++;
				}
				
				if (lineno == line) {
					break;
				}
			}
		}
	}
	
	if (lineno != line) {
		return NSNotFound;
	}
	
	return x;
}

- (void) indicateLine: (int) line {
    // Find out where the line is in the source view
    NSString* store = textStorage.string;
    NSUInteger length = store.length;
	
    NSUInteger x;
    NSUInteger lineLength;
    NSUInteger linepos = 0;
    int        lineno = 1;

    if (line > lineno)
	{
		for (x=0; x<length; x++) {
			unichar chr = [store characterAtIndex: x];
			
			if (chr == '\n' || chr == '\r') {
				unichar otherchar = chr == '\n'?'\r':'\n';
				
				lineno++;
				linepos = x + 1;
				
				// Deal with DOS line endings
				if (linepos < length && [store characterAtIndex: linepos] == otherchar) {
					x++; linepos++;
				}
				
				if (lineno == line) {
					break;
				}
			}
		}
	}
	
    if (lineno != line) {
        NSBeep(); // DOH!
        return;
    }

    lineLength = 0;
    for (x=0; x<length-linepos; x++) {
        if ([store characterAtIndex: x+linepos] == '\n'
			|| [store characterAtIndex: x+linepos] == '\r') {
            break;
        }
        lineLength++;
    }
	
	// Show the find indicator
	[self indicateRange: NSMakeRange(linepos, lineLength)];
}

- (void) updateHighlightedLines {
	[textView.layoutManager removeTemporaryAttribute: NSBackgroundColorAttributeName
                                     forCharacterRange: NSMakeRange(0, textView.textStorage.length)];
	
	// Highlight the lines as appropriate
	for( NSArray* highlight in [self.parent highlightsForFile: openSourceFilepath] ) {
		int line = [highlight[0] intValue];
		IFLineStyle style = [highlight[1] intValue];
		NSColor* background = nil;
		
		switch (style) {
			case IFLineStyleNeutral:
				background = [NSColor colorWithDeviceRed: 0.3 green: 0.3 blue: 0.8 alpha: 1.0];
				break;
				
			case IFLineStyleHighlight:
				background = [NSColor colorWithDeviceRed: 0.3 green: 0.8 blue: 0.8 alpha: 1.0];
				break;
				
			case IFLineStyleError:
				background = [NSColor colorWithDeviceRed: 0.7 green: 0.5 blue: 0.5 alpha: 1.0];
				break;
				
			default:
				background = [NSColor colorWithDeviceRed: 0.8 green: 0.3 blue: 0.3 alpha: 1.0];
				break;
		}
		
		NSRange lineRange = [self findLine: line];
		if ([IFSyntaxManager isRestricted: textStorage
                              forTextView: textView]) {
			NSRange restriction = [IFSyntaxManager restrictedRange: textStorage
                                                       forTextView: textView];
			if (lineRange.location >= restriction.location &&
                lineRange.location < (restriction.location + restriction.length)) {
				lineRange.location -= restriction.location;
			} else {
				lineRange.location = NSNotFound;
			}
		}

		if (lineRange.location != NSNotFound) {
			[textView.layoutManager setTemporaryAttributes: @{NSBackgroundColorAttributeName: background}
											 forCharacterRange: lineRange];
		}
	}
}

#pragma mark - The selection

@synthesize openSourceFilepath;

- (NSString*) currentFile {
	return [(self.parent).document pathForSourceFile: openSourceFilepath];
}

- (int) currentLine {
	NSUInteger selPos = [textView selectedRange].location;
	
	if (selPos >= textStorage.length) return -1;
	
	// Count the number of newlines until the current line
	// (Take account of CRLF or LFCR style things)
	int x;
	int line = 0;
	
	unichar lastNewline = 0;
	
	for (x=0; x<selPos; x++) {
		unichar chr = [textStorage.string characterAtIndex: x];
		
		if (chr == '\n' || chr == '\r') {
			if (lastNewline != 0 && chr != lastNewline) {
				// CRLF combination
				lastNewline = 0;
			} else {
				lastNewline = chr;
				line++;
			}
		} else {
			lastNewline = 0;
		}
	}
	
	return line;
}

- (void) selectTextRange: (NSRange) range {
	// Restrict the range if needed
	if ( [IFSyntaxManager isRestricted: textStorage
                           forTextView: textView] ) {
		NSRange restriction = [IFSyntaxManager restrictedRange: textStorage
                                                   forTextView: textView];
		if (range.location >= restriction.location &&
            range.location < (restriction.location + restriction.length)) {
			range.location -= restriction.location;
		} else {
			// TODO: move to the appropriate section and try again
			return;
		}
	}

	// Display the range
	[textView scrollRangeToVisible: NSMakeRange(range.location, range.length==0?1:range.length)];
    [textView setSelectedRange: range];
}

- (void) moveToLine: (NSInteger) line {
	[self moveToLine: line
		   character: 0];
}

- (void) moveToLine: (NSInteger) line
		  character: (int) chrNo {
    // Find out where the line is in the source view
    NSString* store = textView.textStorage.string;
    NSUInteger length = store.length;

    NSUInteger x;
    NSUInteger lineLength;
    NSUInteger linepos = 0;
    NSInteger  lineno = 1;

	if (line > lineno)
	{
		for (x=0; x<length; x++) {
			unichar chr = [store characterAtIndex: x];
			
			if (chr == '\n' || chr == '\r') {
				unichar otherchar = chr == '\n'?'\r':'\n';
				
				lineno++;
				linepos = x + 1;
				
				// Deal with DOS line endings
				if (linepos < length && [store characterAtIndex: linepos] == otherchar) {
					x++; linepos++;
				}
				
				if (lineno == line) {
					break;
				}
			}
		}
	}
	
    if (lineno != line) {
        NSBeep(); // DOH!
        return;
    }
	
    lineLength = 1;
    for (x=0; x<length; x++) {
        if ([store characterAtIndex: x] == '\n') {
            break;
        }
        lineLength++;
    }
	
	// Add the character position
	linepos += chrNo;
	
    // Time to scroll
	[self selectTextRange: NSMakeRange(linepos,0)];
}

- (void) moveToLocation: (NSInteger) location {
	[self selectTextRange: NSMakeRange(location, 0)];
}

- (void) selectRange: (NSRange) range {
	[textView scrollRangeToVisible: range];
	[textView setSelectedRange: range];
	
	// NOTE: as this is used as part of the undo sequence for pasteSourceCode, this function must not contain an undo action itself
}

- (void) showSourceFile: (NSString*) file {
    if( file == nil ) return;

	if ([[(self.parent).document pathForSourceFile: file] isEqualToString: [(self.parent).document pathForSourceFile: openSourceFilepath]]) {
		// Nothing to do
		return;
	}

    // Get text storage for file
	NSTextStorage* fileStorage = [(self.parent).document storageForFile: file];

	if (fileStorage == nil) return;

    // Start editing text storage
	[fileStorage beginEditing];

    // Remove current selection.
	[textView setSelectedRange: NSMakeRange(0,0)];

    // Update current filepath
	openSourceFilepath = [[(self.parent).document pathForSourceFile: file] copy];

    // Update current storage
    [IFSyntaxManager unregisterTextStorage: textStorage];

	textStorage = fileStorage;
    [textView.layoutManager replaceTextStorage: textStorage];
	textStorage.delegate = self;

    [IFSyntaxManager registerTextStorage: textStorage
                                filename: file.lastPathComponent
                            intelligence: [IFProjectTypes intelligenceForFilename:file]
                             undoManager: [(self.parent).document undoManager]];

    // Stop editing text storage
	[fileStorage endEditing];

    // Is the file editable?
	[textView setEditable: YES];
}

- (int) lineForCharacter: (NSUInteger) charNum
				 inStore: (NSString*) store {
	int result = 0;
	
    NSUInteger length = store.length;
	
    NSUInteger x;
    NSUInteger linepos;
    int lineno;
    lineno = 1;
	for (x=0; x<length; x++) {
		unichar chr = [store characterAtIndex: x];
		
		if (chr == '\n' || chr == '\r') {
			unichar otherchar = chr == '\n'?'\r':'\n';
			
			lineno++;
			linepos = x + 1;
			
			// Deal with DOS line endings
			if (linepos < length && [store characterAtIndex: linepos] == otherchar) {
				x++; linepos++;
			}
			
			if (x > charNum) {
				break;
			} else {
				result = lineno;
			}
		}
	}
	
	return result;
}

- (NSRange) findLine: (NSUInteger) line {
    NSString* store = textStorage.string;
    NSUInteger length = store.length;
	
    NSUInteger x;
    NSUInteger linepos = 0;
    NSUInteger lineno = 1;

    if (line > lineno) {
		for (x=0; x<length; x++) {
			unichar chr = [store characterAtIndex: x];
			
			if (chr == '\n' || chr == '\r') {
				unichar otherchar = chr == '\n'?'\r':'\n';
				
				lineno++;
				linepos = x + 1;
				
				// Deal with DOS line endings
				if (linepos < length && [store characterAtIndex: linepos] == otherchar) {
					x++; linepos++;
				}
				
				if (lineno == line) {
					break;
				}
			}
		}
	}
	
    if (lineno != line) {
        return NSMakeRange(NSNotFound, 0);
    }
	
	// Find the end of this line
	for (x=linepos; x<length; x++) {
        unichar chr = [store characterAtIndex: x];
        
        if (chr == '\n' || chr == '\r') {
			break;
		}
	}
	
	return NSMakeRange(linepos, x - linepos + 1);
}

#pragma mark - Breakpoints

- (BOOL)validateMenuItem:(NSMenuItem*) menuItem {
    return YES;
}

#pragma mark - Spell checking

- (void) setSpellChecking: (BOOL) checkSpelling {
	textView.continuousSpellCheckingEnabled = checkSpelling;
}

#pragma mark - The headings browser

- (NSArray*) toolbarCells {
	return @[sourcePageControl, headerPageControl];
}

#pragma mark - Managing the source text view

- (BOOL) hasFirstResponder {
	// Returns true if this page has the first responder
	
	// Find the first responder that is a view
	NSResponder* firstResponder = textView.window.firstResponder;
	while (firstResponder && ![firstResponder isKindOfClass: [NSView class]]) {
		firstResponder = firstResponder.nextResponder;
	}
	
	// See if the source text view is in the first responder hierarchy
	NSView* respondingView = (NSView*)firstResponder;
	while (respondingView) {
		if (respondingView == textView)  return YES;
		if (respondingView == self.view) return YES;
		respondingView = respondingView.superview;
	}
	
	return NO;
}

- (void) setSourceTextView: (IFSourceFileView*) newSourceText {
	textView = newSourceText;
}

- (IFSourceFileView*) sourceTextView {
	return textView;
}

#pragma mark - The header page

- (void) highlightHeaderSection {
	// Get the text storage
    if( [IFSyntaxManager isRestricted: textStorage
                          forTextView: textView] ) {
		// Work out the line numbers the restriction applies to
		NSRange restriction = [IFSyntaxManager restrictedRange: textStorage
                                                   forTextView: textView];
		
		NSUInteger firstLine = 0;
		NSUInteger finalLine = NSNotFound;

		NSString* store = textStorage.string;
		NSUInteger length = store.length;
		
        NSUInteger x;
        NSUInteger lineno = 1;
        NSUInteger linepos;

		for (x=0; x<length; x++) {
			unichar chr = [store characterAtIndex: x];
			
			if (chr == '\n' || chr == '\r') {
				unichar otherchar = chr == '\n'?'\r':'\n';
				
				lineno++;
				linepos = x + 1;
				
				if (x < restriction.location) firstLine = lineno;
				else if (x < restriction.location + restriction.length) finalLine = lineno;
				else break;
				
				// Deal with DOS line endings
				if (linepos < length && [store characterAtIndex: linepos] == otherchar) {
					x++; linepos++;
				}
			}
		}
		if (finalLine == NSNotFound) finalLine = lineno;
		
		// Highlight the appropriate node
		[headerPage highlightNodeWithLines: NSMakeRange(firstLine, finalLine-firstLine)];
	} else {
		// Highlight nothing
		[headerPage selectNode: nil];
	}
}

-(void) animationFinished:(IFViewAnimator*) viewAnimator
{
    BOOL hasFirstResponder = [self hasFirstResponder];
    if( hasFirstResponder )
    {
        [self setFirstResponder];
    }
}

- (IBAction) toggleHeaderPage: (id) sender {
	if (headerPageShown) {
		// Hide the header page and show the source page
		[headerPage setController: nil];
		scrollView.frame = (self.view.subviews[0]).frame;
		
		// Animate to the new view
		IFViewAnimator* animator = [[IFViewAnimator alloc] init];
		
		[animator setTime: 0.3];
		[animator prepareToAnimateView: self.view.subviews[0]
                             focusView: nil];
		[animator animateTo: scrollView
                  focusView: nil
					  style: IFAnimateLeft
                sendMessage: @selector(animationFinished:)
                   toObject: self];

		sourcePageControl.state = NSControlStateValueOn;
		headerPageControl.state = NSControlStateValueOff;
		headerPageShown = NO;
	} else {
		// Show the header page
		headerPage.controller = (self.parent).headerController;
		headerPage.pageView.frame = (self.view.subviews[0]).frame;
		[self highlightHeaderSection];
		
		// Animate to the new view
		IFViewAnimator* animator = [[IFViewAnimator alloc] init];
		
		[animator setTime: 0.3];
		[animator prepareToAnimateView: self.view.subviews[0]
                             focusView: headerPage.headerView];
		[animator animateTo: headerPage.pageView
                  focusView: headerPage.headerView
					  style: IFAnimateRight
                sendMessage: @selector(animationFinished:)
                   toObject: self];

		sourcePageControl.state = NSControlStateValueOff;
		headerPageControl.state = NSControlStateValueOn;
		headerPageShown = YES;
	}
}

- (IBAction) showHeaderPage: (id) sender {
	if (!headerPageShown) [self toggleHeaderPage: self];
}

- (IBAction) hideHeaderPage: (id) sender {
	if (headerPageShown) [self toggleHeaderPage: self];
}

- (IBAction) showSourcePage: (id) sender {
	if (headerPageShown) [self toggleHeaderPage: self];
}

#pragma mark - Helping out with the cursor

- (CGFloat) cursorOffset {
	// Returns the offset of the cursor (beginning of the current selection) relative to the top
	// of the view
	
	// Retrieve the currently selected range
	NSRange selection = [textView selectedRange];
	
	// Get the offset of this location in the text view
	NSLayoutManager* layout	= textView.layoutManager;
	NSRange glyphRange		= [layout glyphRangeForCharacterRange: selection
											 actualCharacterRange: nil];

	NSRect boundingRect		= [layout boundingRectForGlyphRange: glyphRange
												inTextContainer: textView.textContainer];
	boundingRect.origin.y	+= textView.textContainerOrigin.y;
	
	// Convert to coordinates relative to the containing view
	boundingRect = [textView convertRect: boundingRect
                                  toView: scrollView];
	
	// Offset is the minimum position of the bounding rectangle
	return NSMinY(boundingRect);
}

#pragma mark - Header page delegate methods

- (void) refreshHeaders: (IFHeaderController*) controller {
	// Relayed via the IFHeaderPage (where it's relayed via the view)
	[self highlightHeaderSection];
}

- (void) removeLimits {
    if( [IFSyntaxManager isRestricted: textStorage
                          forTextView: textView] ) {
        NSUndoManager* undo = textView.undoManager;
		[[undo prepareWithInvocationTarget: self] limitToRange: [IFSyntaxManager restrictedRange: textStorage
                                                                                     forTextView: textView]
											 preserveScrollPos: NO];

        // Switch text storage
        [textView.layoutManager replaceTextStorage: textStorage];

        [IFSyntaxManager removeRestriction: textStorage
                               forTextView: textView];
        [self highlightHeaderSection];
        
        [textView setTornAtTop: NO];
        [textView setTornAtBottom: NO];
    }
}

- (void) limitToRange: (NSRange) range
	preserveScrollPos: (BOOL) preserveScrollPos {
	// Record the current cursor offset and selection if preservation is turned on
    CGFloat originalCursorOffset	= 0;
	NSRange selectionRange		= NSMakeRange(0, 0);
	
	if (preserveScrollPos) {
		originalCursorOffset	= [self cursorOffset];
		selectionRange			= [textView selectedRange];
		[textView.layoutManager setBackgroundLayoutEnabled: NO];
	}
	
	// Get the text storage object
	NSUndoManager* undo = textView.undoManager;
   
	if (![IFSyntaxManager isRestricted: textStorage
                           forTextView: textView]) {
        // Set up the restriction
        [IFSyntaxManager restrictStorage: textStorage
                                   range: range
                             forTextView: textView];
        NSTextStorage* restrictedStorage = [IFSyntaxManager restrictedTextStorage: textStorage
                                                                      forTextView: textView];

        [textView.layoutManager replaceTextStorage: restrictedStorage];

		[[undo prepareWithInvocationTarget: self] removeLimits];
	} else {
        NSRange restrictedRange = [IFSyntaxManager restrictedRange: textStorage
                                                       forTextView: textView];
		if (preserveScrollPos) {
			 selectionRange.location += restrictedRange.location;
		}

		[[undo prepareWithInvocationTarget: self] limitToRange: restrictedRange
                                             preserveScrollPos: NO];
        // Set the restriction range
        [IFSyntaxManager restrictStorage: textStorage
                                   range: range
                             forTextView: textView];
	}
	
	[self highlightHeaderSection];
	
	// Display or hide the tears at the top and bottom
	[textView setTornAtTop: range.location!=0];
	[textView setTornAtBottom: (range.location+range.length)<textStorage.length];
    
	// Refresh any highlighting
	[self updateHighlightedLines];
	
	// Reset the selection and try to scroll back to the original position if we can
	if (preserveScrollPos) {
		// Update the selection
		if (range.location < selectionRange.location) {
			// Selection is after the beginning of the range
			selectionRange.location -= range.location;
			
			if (selectionRange.location > range.length) {
				// Selection is after the end of the range; just use the start of the region
				selectionRange.location = selectionRange.length = 0;
			} else if (selectionRange.location + selectionRange.length > range.length) {
				// Selection extends beyond the end of the region
				selectionRange.length = range.length - selectionRange.location;
			}
		} else {
			// Just go to the start of the region if the selection is out of bounds
			selectionRange.location = selectionRange.length = 0;
			
			// TODO: selection could start before the range and extend into it; this will work 
			// differently from the selection extending over the end of the range
		}
		
		// Set the selection
		[textView setSelectedRange: selectionRange];
		
		// Scroll to the top to avoid some glitching
		[textView scrollPoint: NSMakePoint(0,0)];

		// Get the cursor scroll offset
        CGFloat newCursorOffset	    = [self cursorOffset];
        CGFloat scrollOffset		= floor(newCursorOffset - originalCursorOffset);
		
		// Scroll the view
		NSPoint scrollPos = scrollView.contentView.documentVisibleRect.origin;
		NSLog(@"Old offset: %g, new offset %g, adjusted scroll by %g from %g", originalCursorOffset, newCursorOffset, scrollOffset, scrollPos.y);
		scrollPos.y += scrollOffset;
		if (range.location > 0) scrollPos.y += 18;			// HACK
		if (scrollPos.y < 0) scrollPos.y = 0;
		[scrollView.contentView scrollToPoint: scrollPos];

		[textView.layoutManager setBackgroundLayoutEnabled: YES];
	}
}

- (void) limitToSymbol: (IFIntelSymbol*) symbol 
	 preserveScrollPos: (BOOL)preserveScrollPos {
	IFIntelFile* intelFile = (self.parent).headerController.intelFile;
	IFIntelSymbol* followingSymbol	= symbol.sibling;
	
	if (symbol == nil || symbol == intelFile.firstSymbol) {
		// Remove the source text limitations
		[self removeLimits];
		
		// Scroll to the top
		[textView scrollPoint: NSMakePoint(0,0)];
		
		// Redisplay the source code
		if (headerPageShown) [self toggleHeaderPage: self];
		
		return;
	}
	
	if (followingSymbol == nil) {
		IFIntelSymbol* parentSymbol = symbol.parent;
		
		while (parentSymbol && !followingSymbol) {
			followingSymbol = parentSymbol.sibling;
			parentSymbol = parentSymbol.parent;
		}
	}
	
	// Get the range we need to limit to
	NSRange limitRange;
	
	NSUInteger symbolLine = [intelFile lineForSymbol: symbol];
	if (symbolLine == NSNotFound) return;
	
	limitRange.location = [self indexOfLine: symbolLine
								   inString: textStorage.string];
	
	NSUInteger finalLocation;
	if (followingSymbol) {
		NSUInteger followingLine = [intelFile lineForSymbol: followingSymbol];
		if (followingLine == NSNotFound) return;
		finalLocation = [self indexOfLine: followingLine
								 inString: textStorage.string];
	} else {
		finalLocation = textStorage.length;
	}
	
	if (finalLocation == NSNotFound) return;
	
	// Move the start of the limitation to the first non-whitespace character
	while (limitRange.location < finalLocation) {
		unichar chr = [textStorage.string characterAtIndex: limitRange.location];
		if (chr != ' ' && chr != '\t' && chr != '\n' && chr != '\r') {
			break;
		}
		limitRange.location++;
	}
	
	// Perform the limitation
	limitRange.length = finalLocation - limitRange.location;
	[self limitToRange: limitRange
	 preserveScrollPos: preserveScrollPos];
	
	// Redisplay the source code
	if (headerPageShown) [self toggleHeaderPage: self];
	
	// Scroll to the top
	if (!preserveScrollPos) {
		[textView scrollPoint: NSMakePoint(0,0)];
	}
}

- (void) headerPage: (IFHeaderPage*) page
	  limitToHeader: (IFHeader*) header {
	// Work out the following symbol
	IFIntelSymbol* symbol			= header.symbol;
	
	[self limitToSymbol: symbol
	  preserveScrollPos: NO];
}

- (void) undoReplaceCharactersInRange: (NSRange) range
						   withString: (NSString*) string {
	// Create an undo action
	NSUndoManager* undo = [self undoManagerForTextView: textView];

    [[undo prepareWithInvocationTarget: self] undoReplaceCharactersInRange: NSMakeRange(range.location, string.length)
																withString: [textStorage.string substringWithRange: range]];
	[undo setActionName: [IFUtility localizedString: @"Edit Header"]];
	
	// Replace the text for this range
	[textStorage.mutableString replaceCharactersInRange: range
                                               withString: string];
}

- (void) headerView: (IFHeaderView*) view
 		 updateNode: (IFHeaderNode*) node
 	   withNewTitle: (NSString*) newTitle {
	IFHeader* header = node.header;
	IFIntelSymbol* symbol = header.symbol;
	IFIntelFile* intel = self.currentIntelligence;

	NSString* lastValue = header.headingName;
	
	// Work out which line needs to be edited
	NSUInteger line = [intel lineForSymbol: symbol] + 1;
	
	// Get the range of the line
	NSRange lineRange = [self findLine: line];
	if (lineRange.location == NSNotFound) return;
	
	NSString* currentValue = [textStorage.string substringWithRange: lineRange];
	
	// If the line currently contains the previous value, then replace it with the new value
	if ([currentValue isEqualToString: lastValue] && ![currentValue isEqualToString: newTitle]) {
		// Restrict to the selected node
		[self headerPage: nil
		   limitToHeader: header];

		// Create an undo action
		NSUndoManager* undo = [self undoManagerForTextView: textView];
		[[undo prepareWithInvocationTarget: self] undoReplaceCharactersInRange: NSMakeRange(lineRange.location, newTitle.length)
																	withString: [textStorage.string substringWithRange: lineRange]];
		[undo setActionName: [IFUtility localizedString: @"Edit Header"]];
		
		// Replace the text for this node
		[textStorage.mutableString replaceCharactersInRange: lineRange
                                                   withString: newTitle];
	}
	
	[(self.parent).headerController updateFromIntelligence: self.currentIntelligence];
}
	
- (IFIntelSymbol*) currentSection {
	// Get the text storage
	if ([IFSyntaxManager isRestricted: textStorage
                          forTextView: textView]) {
		IFIntelFile* intelFile = self.currentIntelligence;
		
		// Work out the line numbers the restriction applies to
		NSRange restriction = [IFSyntaxManager restrictedRange: textStorage
                                                   forTextView: textView];

		// Return the nearest section
		return [intelFile nearestSymbolToLine: [self lineForCharacter: restriction.location
															  inStore: textStorage.string]];
	}
	
	return nil;
}

- (void) sourceFileShowPreviousSection: (id) sender {
	IFIntelSymbol* section = [self currentSection];
	IFIntelSymbol* previousSection = section.previousSibling;
	
	if (!previousSection) {
		previousSection = section.parent;
		if (previousSection == self.currentIntelligence.firstSymbol) previousSection = nil;
	}

	if (previousSection) {
		IFViewAnimator* animator = [[IFViewAnimator alloc] init];

		[animator setTime: 0.1];
		[animator prepareToAnimateView: self.view
                             focusView: nil];
		
		[self limitToSymbol: previousSection
		  preserveScrollPos: NO];
		[textView setSelectedRange: NSMakeRange(0,0)];
		[animator animateTo: self.view
                  focusView: textView
					  style: IFAnimateDown
                sendMessage: @selector(animationFinished:)
				   toObject: self];
	} else {
		IFViewAnimator* animator = [[IFViewAnimator alloc] init];

		[animator setTime: 0.1];
		[animator prepareToAnimateView: self.view
                             focusView: nil];
		
		[self removeLimits];
		[textView setSelectedRange: NSMakeRange(0,0)];
		[animator animateTo: self.view
                  focusView: textView
					  style: IFAnimateDown
				sendMessage: @selector(animationFinished:)
				   toObject: self];
	}
}

- (void) sourceFileShowNextSection: (id) sender {
	IFIntelSymbol* section		= [self currentSection];
	IFIntelSymbol* nextSection	= section.sibling;
	
	if (!nextSection) {
		IFIntelSymbol* parentSection = section.parent;
		while (parentSection && !nextSection) {
			nextSection = parentSection.sibling;
			parentSection = parentSection.parent;
		}
	}
	
	if (nextSection) {
		IFViewAnimator* animator = [[IFViewAnimator alloc] init];

		[animator setTime: 0.3];
		[animator prepareToAnimateView: self.view
                             focusView: nil];
		
		[self limitToSymbol: nextSection
		  preserveScrollPos: NO];
		[textView setSelectedRange: NSMakeRange(0,0)];
		[animator animateTo: self.view
                  focusView: textView
					  style: IFAnimateUp
				sendMessage: @selector(animationFinished:)
				   toObject: self];
	}
}

- (void) setFirstResponder {
	// View animation has finished and we want to reset the source text view as the first responder
	[textView.window makeFirstResponder: textView];
}

- (IFIntelSymbol*) symbolNearestSelection {
	// Work out the absolute selection
	NSRange selection				= [textView selectedRange];
	if ([IFSyntaxManager isRestricted: textStorage
                          forTextView: textView]) {
		selection.location			+= [IFSyntaxManager restrictedRange: textStorage
                                                            forTextView: textView].location;
	}
	
	// Retrieve the symbol nearest to the line the selection is on
	IFIntelFile* intelFile			= self.currentIntelligence;
	IFIntelSymbol* nearestSymbol	= [intelFile nearestSymbolToLine: [self lineForCharacter: selection.location
																				  inStore: textStorage.string]];
	
	return nearestSymbol;
}

- (void) showEntireSource: (id) sender {
	// Display everything
	[self limitToRange: NSMakeRange(0, textStorage.length)
	 preserveScrollPos: YES];
}

- (void) showCurrentSectionOnly: (id) sender {
	// Get the symbol nearest to the current selection
	IFIntelSymbol* cursorSection = [self symbolNearestSelection];
	
	// Limit the displayed range to it
	if (cursorSection) {
		[self limitToSymbol: cursorSection
		  preserveScrollPos: YES];
	}
}

- (void) showFewerHeadings: (id) sender {
	// Get the currently displayed section
	IFIntelSymbol* currentSection = [self currentSection];
	if (!currentSection) {
		// Ensures we don't end up picking the 'title' section which includes the whole file anyway
		currentSection = self.currentIntelligence.firstSymbol;
	}
	
	// Also get the section that the cursor is in
	IFIntelSymbol* cursorSection = [self symbolNearestSelection];
	
	// Can't do anything if the cursor is in no section, or the currently selected section is the most specific we can use
	if (cursorSection == nil || currentSection == cursorSection) {
		return;
	}
	
	// Move up the sections until we find one which has the currentSection as a parent
	IFIntelSymbol* lowerSection = cursorSection;
	while (lowerSection && lowerSection.parent != currentSection) {
		lowerSection = lowerSection.parent;
	}
	
	if (lowerSection) {
		// Restrict to this section
		[self limitToSymbol: lowerSection
		  preserveScrollPos: YES];
	}
}

- (void) showMoreHeadings: (id) sender {
	// Limit to one section above the current section
	IFIntelSymbol* currentSection	= [self currentSection];
	if (!currentSection) {
		return;
	}
	
	IFIntelSymbol* parentSection	= currentSection.parent;
	if (parentSection && parentSection != self.currentIntelligence.firstSymbol) {
		[self limitToSymbol: parentSection
		  preserveScrollPos: YES];
	} else {
		[self showEntireSource: self];
	}
}

- (void) preferencesChanged: (NSNotification*) not {
    [self setBackgroundColour];
    [textView setNeedsDisplay:YES];
}

@end
