//
//  IFSingleController.m
//  Inform
//
//  Created by Andrew Hunter on 25/06/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFSingleFile.h"
#import "IFSingleController.h"
#import "IFWelcomeWindow.h"
#import "IFPreferences.h"
#import "IFExtensionsManager.h"
#import "IFAppDelegate.h"
#import "IFProjectController.h"
#import "IFSyntaxManager.h"
#import "IFUtility.h"
#import "IFSourceFileView.h"

@interface IFSingleController(PrivateMethods)

- (void) showInstallPrompt: (id) sender;
- (void) hideInstallPrompt: (id) sender;

@end

@implementation IFSingleController {
    IBOutlet IFSourceFileView*	fileView;						// The textview used to display the document itself
    IBOutlet NSView*			installWarning;					// The view used to warn when a .i7x file is not installed
    IBOutlet NSView*			mainView;						// The 'main view' that fills the window when the install warning is hidden
    BOOL                        isExtension;
    BOOL                        isInform7;
    NSRange                     initialSelectionRange;

    IFSourceSharedActions*      sharedActions;
}

-(instancetype) initWithInitialSelectionRange: (NSRange) anInitialSelectionRange {
    self = [super initWithWindowNibName: @"SingleFile"];
    if( self ) {
        sharedActions = [[IFSourceSharedActions alloc] init];
        
        initialSelectionRange = anInitialSelectionRange;
        
        // Notification
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(preferencesChanged:)
                                                     name: IFPreferencesEditingDidChangeNotification
                                                   object: [IFPreferences sharedPreferences]];
    }
    return self;
}

- (void) dealloc {
    // Notification
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	// Unset the view's text storage
	if (fileView != nil) {
		[[[self document] storage] removeLayoutManager: [fileView layoutManager]];
	}

    sharedActions = nil;
}

- (void)windowDidLoad {
	[IFWelcomeWindow hideWelcomeWindow];
}

- (void) awakeFromNib {
	// Set the window frame save name
	[self setWindowFrameAutosaveName: @"SingleFile"];
	
	// Set the view's text appropriately
    [fileView.layoutManager replaceTextStorage: [[self document] storage]];
	
	[fileView setEditable: ![[self document] isReadOnly]];
    [fileView setRichText: NO];
    [fileView setEnabledTextCheckingTypes: 0];
    [fileView setSelectedRange: initialSelectionRange];

	NSString* filename = [[[[self document] fileURL] path] stringByStandardizingPath];
    NSString* dotExtension = [[filename pathExtension] lowercaseString];

	isExtension = [dotExtension isEqualToString: @"i7x"] ||
                  [dotExtension isEqualToString: @"h"] ||
                  [dotExtension isEqualToString: @""];
    isInform7 = [dotExtension isEqualToString: @"i7x"] ||
                [dotExtension isEqualToString: @"ni"] ||
                [dotExtension isEqualToString: @"i7"] ||
                [dotExtension isEqualToString: @""];
    
	// If this is an Inform 7 extension then test to see if we're editing it from within the extensions directory or not
	BOOL isInstalled = NO;

	if ( isInform7 && isExtension ) {
		// Iterate through the i7 extension directories
        IFExtensionsManager* manager = [IFExtensionsManager sharedNaturalInformExtensionsManager];
        if( [manager isFileInstalled: filename] ) {
            isInstalled = YES;
        }

        // If this file isn't installed, then create the 'install this file' prompt
        if (!isInstalled) {
            [self showInstallPrompt: self];
        }
	}

    // Spell checking
    [self setSourceSpellChecking: [(IFAppDelegate *) [NSApp delegate] sourceSpellChecking]];

    [self setBackgroundColour];
}

#pragma mark - Menu items

- (BOOL)validateMenuItem:(NSMenuItem*) menuItem {
	SEL itemSelector = [menuItem action];

	if (itemSelector == @selector(saveDocument:)) {
		return ![[self document] isReadOnly];
	}
	// Format options
	if (itemSelector == @selector(shiftLeft:) ||
		itemSelector == @selector(shiftRight:) ||
		itemSelector == @selector(renumberSections:)) {
		// First responder must be an NSTextView object
		if (![[[self window] firstResponder] isKindOfClass: [NSTextView class]])
			return NO;
	}
	
	if (itemSelector == @selector(commentOutSelection:) ||
        itemSelector == @selector(uncommentSelection:)) {
		// Must be an Inform 7 file
		if (!isInform7) {
			return NO;
        }

		// First responder must be a NSTextView object
		if (![[[self window] firstResponder] isKindOfClass: [NSTextView class]]) {
			return NO;
        }

		// There must be a non-zero length selection
		if ([(NSTextView*)[[self window] firstResponder] selectedRange].length == 0) {
			return 0;
        }
	}
	
	if (itemSelector == @selector(renumberSections:)) {
        NSResponder* responder = [[self window] firstResponder];

		// First responder must be an NSTextView object containing a NSTextStorage with some intel data
		if (![responder isKindOfClass: [NSTextView class]]) {
			return NO;
        }

		NSTextStorage* storage = [(NSTextView*)responder textStorage];
		if ([IFSyntaxManager intelligenceDataForStorage: storage] == nil) return NO;
	}
	
	return YES;
}

- (void) setSourceSpellChecking: (BOOL) spellChecking {
    [fileView setContinuousSpellCheckingEnabled: spellChecking];
}

- (void) commentOutSelection: (id) sender {
    NSResponder* responder = [[self window] firstResponder];

    if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions commentOutSelectionInDocument: [self document]
                                            textView: (NSTextView *) responder];
    }
}

- (void) uncommentSelection: (id) sender {
    NSResponder* responder = [[self window] firstResponder];
    
    if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions uncommentSelectionInDocument: [self document]
                                           textView: (NSTextView *) responder];
    }
}

- (IBAction) shiftLeft: (id) sender {
    NSResponder* responder = [[self window] firstResponder];
    
    if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions shiftLeftTextViewInDocument: [self document]
                                          textView: (NSTextView *) responder];
    }
}

- (IBAction) shiftRight: (id) sender {
    NSResponder* responder = [[self window] firstResponder];
    
    if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions shiftRightTextViewInDocument: [self document]
                                           textView: (NSTextView *) responder];
    }
}

- (IBAction) renumberSections: (id) sender {
    NSResponder* responder = [[self window] firstResponder];
    
    if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions renumberSectionsInDocument: [self document]
                                         textView: (NSTextView *) responder];
    }
}

#pragma mark - Showing/hiding the installation prompt

- (void) showInstallPrompt: (id) sender {
	// Get the view that the warning should be displayed in
	NSView* parentView = [mainView superview];

	// Do nothing if the view is already displayed (if it's displayed somewhere random this is going to go wrong)
	if ([installWarning superview] == parentView) {
		return;
	} else if ([installWarning superview] != nil) {
		[installWarning removeFromSuperview];
	}
	
	// Resize the main view
	NSRect warningFrame			= [installWarning frame];
	NSRect mainViewFrame		= [mainView frame];
	mainViewFrame.size.height	-= warningFrame.size.height;
	
	[mainView setFrame: mainViewFrame];
	
	// Position the warning view
	warningFrame.origin.x		= NSMinX(mainViewFrame);
	warningFrame.origin.y		= NSMaxY(mainViewFrame);
	warningFrame.size.width		= mainViewFrame.size.width;
	
	[parentView addSubview: installWarning];
	[installWarning setFrame: warningFrame];
}

- (void) hideInstallPrompt: (id) sender {
	// Get the view that the warning should be displayed in
	NSView* parentView = [mainView superview];
	
	// Do nothing if the view not already displayed (if it's displayed somewhere random this is going to go wrong)
	if ([installWarning superview] != parentView) {
		return;
	}
	
	// Remove it from the view
	[installWarning removeFromSuperview];
	
	// Resize the main view
	NSRect warningFrame			= [installWarning frame];
	NSRect mainViewFrame		= [mainView frame];
	mainViewFrame.size.height	+= warningFrame.size.height;
	
	[mainView setFrame: mainViewFrame];
}

#pragma mark - Installer actions

- (IBAction) installFile: (id) sender {
	// Install this extension
	NSString* finalPath = nil;
    IFExtensionResult installResult = [[IFExtensionsManager sharedNaturalInformExtensionsManager]
                                           installExtension: [[[self document] fileURL] path]
                                                  finalPath: &finalPath
                                                      title: nil
                                                     author: nil
                                                    version: nil
                                         showWarningPrompts: YES
                                                     notify: YES];
	if (installResult == IFExtensionSuccess) {
		// Find the new path
        [[self document] setFileURL: [NSURL fileURLWithPath: finalPath]];
        // Hide the install prompt
        [self hideInstallPrompt: self];
	} else {
        // Warn that the extension couldn't be installed
        [IFUtility showExtensionError: installResult
                           withWindow: [self window]];
	}
}

- (IBAction) cancelInstall: (id) sender {
	// Hide the install prompt
	[self hideInstallPrompt: self];
}

#pragma mark - Highlighting lines

- (void) highlightSourceFileLine: (NSInteger) line
						  inFile: (NSString*) file
                           style: (IFLineStyle) style {
    // Find out where the line is in the source view
    NSString* store = [[[self document] storage] string];
    NSUInteger length = [store length];
	
    NSUInteger x, lineno, linepos, lineLength;
    lineno = 1; linepos = 0;
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
	NSRange range = NSMakeRange(linepos, lineLength);
	[fileView setSelectedRange: range];
    [fileView scrollRangeToVisible: range];
    [fileView showFindIndicatorForRange: range];
}

- (void) indicateRange: (NSRange) rangeToIndicate {
    //
    // Indicates a range of text (scrolling to show the match if necessary).
    // Used when user clicks on a search result for 'Find In Files'
    //
	[fileView setSelectedRange: NSMakeRange(rangeToIndicate.location, 0)];
    [fileView scrollRangeToVisible: rangeToIndicate];
    [fileView setSelectedRange: rangeToIndicate];
    [fileView showFindIndicatorForRange: rangeToIndicate];
}

-(void) setBackgroundColour {
    if( isExtension ) {
        [fileView setBackgroundColor: [[IFPreferences sharedPreferences] getExtensionPaper].colour];
    }
    else {
        [fileView setBackgroundColor: [[IFPreferences sharedPreferences] getSourcePaper].colour];
    }
}

- (void) setContinuousSpelling:(BOOL) continuousSpelling {
    [fileView setContinuousSpellCheckingEnabled: continuousSpelling];
}

- (void) preferencesChanged: (NSNotification*) not {
    [self setBackgroundColour];
    [fileView setNeedsDisplay:YES];
}

@end
