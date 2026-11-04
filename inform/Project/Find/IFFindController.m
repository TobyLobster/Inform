//
//  IFFindController.m
//  Inform
//
//  Created by Andrew Hunter on 05/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import "IFFindController.h"
#import "IFFindResult.h"
#import "Inform-Swift.h"
#import "IFUtility.h"

static NSString* const IFFindHistoryPref		= @"IFFindHistory";
static NSString* const IFReplaceHistoryPref	    = @"IFReplaceHistory";

#define FIND_HISTORY_LENGTH 30

@implementation IFFindController {
    // The components of the find dialog
    IBOutlet NSComboBox*	findPhrase;									// The phrase to search for
    IBOutlet NSComboBox*	replacePhrase;								// The phrase to replace it with

    // Ignore case radio button
    IBOutlet NSButton*		ignoreCase;									// The 'ignore case' checkbox

    // Pull down menu of how to search
    /// The 'contains/begins with/complete word/regexp' pop-up button
    IBOutlet NSPopUpButton* searchType;
    /// Choices for the type of object to find
    IBOutlet NSMenuItem*	containsItem;
    IBOutlet NSMenuItem*	beginsWithItem;
    IBOutlet NSMenuItem*	completeWordItem;
    IBOutlet NSMenuItem*	regexpItem;

    // Buttons
    IBOutlet NSButton*		next;
    IBOutlet NSButton*		previous;
    IBOutlet NSButton*		replaceAndFind;
    IBOutlet NSButton*		replace;
    IBOutlet NSButton*		findAll;
    IBOutlet NSButton*		replaceAll;

    // Progress
    /// The 'searching' progress indicator
    IBOutlet NSProgressIndicator* findProgress;

    // Parent view to position extra content
    IBOutlet NSView*		auxViewPanel;								// The auxilary view panel

    // The regular expression help view
    IBOutlet NSView*		regexpHelpView;								// The view containing information about regexps

    // The 'find all' views
    IBOutlet NSView*		foundNothingView;							// The view to show if we don't find any matches
    IBOutlet NSView*		findAllView;								// The main 'find all' view
    IBOutlet NSTableView*	findAllTable;								// The 'find all' results table
    IBOutlet NSTextField*   findCountText;                              // Text of how many results we have
    CGFloat                 borders;                                    // Height of the window with the find all view open, but without the results table. A constant.

    // Things we've searched for
    NSMutableArray*			replaceHistory;								// The 'replace' history
    NSMutableArray*			findHistory;								// The 'find' history
    NSString*				lastSearch;									// The last phrase that was searched for
    NSMenuItem*             lastSearchType;                             // The last search type that was searched with
    BOOL                    lastSearchIgnoreCase;                       // The last searches 'ignore case' flag

    BOOL					searching;									// YES if we're searching for results
    NSMutableArray*			findAllResults;								// The 'find all' results view
    int						findAllCount;								// Used to generate the identifier
    id						findIdentifier;								// The current find all identifier
    NSRect                  textViewSize;								// The original size of the text view

    // Auxiliary views
    NSView* auxView;													// The auxiliary view that is being displayed
    NSRect winFrame;													// The default window frame
    NSRect contentFrame;												// The default size of the content frame
    
    // The delegate
    /// The delegate that we've chosen to work with
    __weak id<IFFindDelegate> activeDelegate;
}


#pragma mark - Initialisation

+ (IFFindController*) sharedFindController {
	static IFFindController* sharedController = nil;
	
	if (!sharedController) {
		sharedController = [[IFFindController alloc] initWithWindowNibName: @"Find"];
	}
	
	return sharedController;
}

- (instancetype) initWithWindowNibName: (NSString*) nibName {
	self = [super initWithWindowNibName: (NSString*) nibName];
	
	if (self) {
		// Get notifications about when the main window changes
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(mainWindowChanged:)
													 name: NSWindowDidBecomeMainNotification
												   object: nil];
		
		// Get the find/replace history
		findHistory = [[[NSUserDefaults standardUserDefaults] objectForKey: IFFindHistoryPref] mutableCopy];
		replaceHistory = [[[NSUserDefaults standardUserDefaults] objectForKey: IFReplaceHistoryPref] mutableCopy];
		
		if (!findHistory)		findHistory		= [[NSMutableArray alloc] init];
		if (!replaceHistory)	replaceHistory	= [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void) dealloc {
	// Stop receiving notifications
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	
	// Finish up
}

#pragma mark - Updating the history

- (void) addPhraseToFindHistory: (NSString*) phrase {
	phrase = [phrase copy];
	
	// Ensure that we don't store a duplicate copy of the phrase
	NSUInteger lastIndex = [findHistory indexOfObject: phrase];
	if (lastIndex != NSNotFound) {
		[findHistory removeObjectAtIndex: lastIndex];
	}
	
	// Insert the new phrase into the find history
	[findHistory insertObject: phrase
					  atIndex: 0];
	
	// Ensure that we limit the number of items in the history
	while (findHistory.count > FIND_HISTORY_LENGTH) {
		[findHistory removeLastObject];
	}
	
	// Store in the user defaults
	[[NSUserDefaults standardUserDefaults] setObject: [findHistory copy]
											  forKey: IFFindHistoryPref];
	
	// Update the combo box
	[findPhrase reloadData];
}

- (void) addPhraseToReplaceHistory: (NSString*) phrase {
	phrase = [phrase copy];
	
	// Ensure that we don't store a duplicate copy of the phrase
	NSUInteger lastIndex = [replaceHistory indexOfObject: phrase];
	if (lastIndex != NSNotFound) {
		[replaceHistory removeObjectAtIndex: lastIndex];
	}
	
	// Insert the new phrase into the find history
	[replaceHistory insertObject: phrase
						 atIndex: 0];
	
	// Ensure that we limit the number of items in the history
	while (replaceHistory.count > FIND_HISTORY_LENGTH) {
		[replaceHistory removeLastObject];
	}
	
	// Store in the user defaults
	[[NSUserDefaults standardUserDefaults] setObject: [replaceHistory copy]
											  forKey: IFReplaceHistoryPref];
	
	// Update the combo box
	[replacePhrase reloadData];
}

#pragma mark - Actions

- (IFFindType) currentFindType {
	NSMenuItem* selected = searchType.selectedItem;
	
	IFFindType flags = 0;
	if (ignoreCase.state == NSControlStateValueOn) flags |= IFFindCaseInsensitive;
	
	if (selected == containsItem) {
		return IFFindContains | flags;
	} else if (selected == beginsWithItem) {
		return IFFindBeginsWith | flags;
	} else if (selected == completeWordItem) {
		return IFFindCompleteWord | flags;
	} else if (selected == regexpItem) {
		return IFFindRegexp | flags;
	} else {
		return IFFindContains | flags;
	}
}

- (void) setLastSearch: (NSString*) phrase {
	if (![phrase isEqualToString: lastSearch]) {
		// Set the last search phrase
		lastSearch = [phrase copy];
		
		// Close the 'find all' results
		[self showAuxiliaryView: nil];
	}

    lastSearchType = searchType.selectedItem;
    lastSearchIgnoreCase = (ignoreCase.state == NSControlStateValueOn);
}

- (IBAction) findNext: (id) sender {
    if( findPhrase.stringValue.length == 0 ) {
        return;
    }

    if ([activeDelegate respondsToSelector: @selector(findNextMatch:ofType:completionHandler:)]) {
		// Close the 'all' dialog if necessary
		[self setLastSearch: findPhrase.stringValue];
		
		// Get the delegate to perform the search
		[activeDelegate findNextMatch: findPhrase.stringValue
							   ofType: [self currentFindType]
                    completionHandler: nil];

		// Record the phrase in the history
		[self addPhraseToFindHistory: findPhrase.stringValue];
	}
}

- (IBAction) findPrevious: (id) sender {
    if( findPhrase.stringValue.length == 0 ) {
        return;
    }

    if ([activeDelegate respondsToSelector: @selector(findPreviousMatch:ofType:completionHandler:)]) {
		// Close the 'all' dialog if necessary
		[self setLastSearch: findPhrase.stringValue];
		
		// Get the delegate to perform the search
		[activeDelegate findPreviousMatch: findPhrase.stringValue
								   ofType: [self currentFindType]
                        completionHandler: nil];

		// Record the phrase in the history
		[self addPhraseToFindHistory: findPhrase.stringValue];
	}
}

- (IBAction) replaceAndFind: (id) sender {
    if( findPhrase.stringValue.length == 0 ) {
        return;
    }
	if (activeDelegate 
		&& [activeDelegate respondsToSelector: @selector(replaceFoundWith:)]
        && [activeDelegate respondsToSelector:@selector(findNextMatch:ofType:completionHandler:)]) {
		
        NSString* replaceString;
		if( ([self currentFindType] & 0xff) == IFFindRegexp ) {
    		// The replace string has \1 \2 etc translated into actual string values using the last found regex groups
            replaceString = [IFFindResult stringByReplacingGroups:replacePhrase.stringValue regexFoundGroups:activeDelegate.lastFoundGroups];
        } else {
            replaceString = replacePhrase.stringValue;
        }

		[self addPhraseToReplaceHistory: replaceString];
		[activeDelegate replaceFoundWith: replaceString];
		[activeDelegate findNextMatch: findPhrase.stringValue
							   ofType: [self currentFindType]
                    completionHandler: nil];
	}
}

- (IBAction) replace: (id) sender {
	if ([activeDelegate respondsToSelector: @selector(replaceFoundWith:)]) {
		[self addPhraseToReplaceHistory: replacePhrase.stringValue];
		[activeDelegate replaceFoundWith: replacePhrase.stringValue];
	}
}

- (IBAction) useSelectionForFind: (id) sender {
	// Hack: ensure the window is loaded
	[self window];
	
    if ([activeDelegate respondsToSelector: @selector(currentSelectionForFindWithCompletionHandler:)]) {
        [activeDelegate currentSelectionForFindWithCompletionHandler: ^(NSString* searchFor) {
            if (searchFor && ![@"" isEqualToString: searchFor]) {
                self->findPhrase.stringValue = searchFor;
                [self->searchType selectItem: self->containsItem];

                [self findNext: self];
                return;
            } else {
                NSBeep();
            }
        }];
	}
}

- (IBAction) findTypeChanged: (id) sender {
	if (searchType.selectedItem == regexpItem) {
		[self showAuxiliaryView: regexpHelpView];
	} else {
		if (auxView == regexpHelpView) {
			[self showAuxiliaryView: nil];
		}
	}
}

#pragma mark - Find menu actions

- (BOOL) canFindAgain: (id) sender {
	if (activeDelegate && ![@"" isEqualToString: findPhrase.stringValue]) {
		return YES;
	} else {
		return NO;
	}
}

- (BOOL) canUseSelectionForFind: (id) sender {
    return YES;
}

#pragma mark - Updating the find delegate

- (BOOL) isSuitableDelegate: (id) object {
	if (!object) return NO;
	
    if ([object respondsToSelector: @selector(findNextMatch:ofType:completionHandler:)]) {
		return YES;
	} else {
		return NO;
	}
}

- (id<IFFindDelegate>) chooseDelegateFromWindow: (NSWindow*) window {
	// Default delegate behaviour is to look at the window controller first, then the window, then the views
	// up the chain from the active view
    NSWindowController* controller = window.windowController;
    if ([self isSuitableDelegate: controller]) {
        return (id<IFFindDelegate>)controller;
	} else if ([self isSuitableDelegate: window]) {
		return (id<IFFindDelegate>)window;
	}
	
	NSResponder* responder = window.firstResponder;
	while (responder) {
		if ([self isSuitableDelegate: responder]) {
			return (id<IFFindDelegate>)responder;
		}
		responder = responder.nextResponder;
	}
	
	return nil;
}

- (BOOL) canSearch {
    return [activeDelegate respondsToSelector: @selector(findNextMatch:ofType:completionHandler:)];
}

- (BOOL) canReplace {
	return [activeDelegate respondsToSelector: @selector(replaceFoundWith:)];
}

- (BOOL) canFindAll {
	return [activeDelegate respondsToSelector: @selector(findAllMatches:ofType:inLocation:inFindController:withIdentifier:)];
}

- (BOOL) canReplaceAll {
	return [activeDelegate respondsToSelector: @selector(replaceFindAllResult:withString:offset:)];
}

- (BOOL) supportsFindType: (IFFindType) type {
	if (activeDelegate) {
		if ([activeDelegate respondsToSelector: @selector(canUseFindType:)]) {
			// If the delegate specifies what types of thing it can find, then use that
			return [activeDelegate canUseFindType: type];
		} else {
			// Default is to support all but regular expressions
			if (type == IFFindRegexp) return NO;
			return YES;
		}
	}
	
	// If there's no delegate, allow everything
	return YES;
}

- (void) updateControls: (BOOL) copyLastState {
	findPhrase.enabled = [self canSearch] || [self canFindAll];
	replacePhrase.enabled = [self canReplace];
	
	ignoreCase.enabled = [self canSearch];
	searchType.enabled = [self canSearch];
	
	containsItem.enabled = [self supportsFindType: IFFindContains];
	beginsWithItem.enabled = [self supportsFindType: IFFindBeginsWith];
	completeWordItem.enabled = [self supportsFindType: IFFindCompleteWord];
	regexpItem.enabled = [self supportsFindType: IFFindRegexp];

    BOOL hasSearchTerm = findPhrase.stringValue.length > 0;

	next.enabled = [self canSearch] && hasSearchTerm;
	previous.enabled = [self canSearch] && hasSearchTerm;
	replaceAndFind.enabled = [self canReplace] && hasSearchTerm;
	replace.enabled = [self canReplace] && hasSearchTerm;
	replaceAll.enabled = [self canReplaceAll] && hasSearchTerm;
	findAll.enabled = [self canFindAll] && hasSearchTerm;

    if (copyLastState) {
        // 'Contains' is the basic type of search
        if ((lastSearchType == nil) || (!lastSearchType.enabled)) {
            [searchType selectItem: containsItem];
        }
        else {
            [searchType selectItem: lastSearchType];
        }

        ignoreCase.state = (lastSearchIgnoreCase) ? NSControlStateValueOn : NSControlStateValueOff;
    }
}

- (void) setActiveDelegate: (id<IFFindDelegate>) newDelegate {
	if (newDelegate == activeDelegate) return;
	
	activeDelegate = newDelegate;

    findIdentifier = nil;

	if (searching) {
		[findProgress stopAnimation: self];
		searching = NO;
	}
	if (auxView != regexpHelpView) {
		[self showAuxiliaryView: nil];
	}

    [self updateControls: NO];
}

- (void) updateFromFirstResponder {
	NSWindow* mainWindow = NSApp.mainWindow;
	[self setActiveDelegate: [self chooseDelegateFromWindow: mainWindow]];
}

- (void) mainWindowChanged: (NSNotification*) not {
	// Update this control from the first responder
	[self setActiveDelegate: [self chooseDelegateFromWindow: not.object]];
}
						   
- (void) windowDidLoad {
	[self updateFromFirstResponder];
    [self updateControls: YES];

	winFrame		= self.window.frame;
	contentFrame	= self.window.contentView.frame;
    borders         = self.window.frame.size.height + findAllView.frame.size.height - findAllTable.frame.size.height;

    // When clicked, call the routine
    findAllTable.action = @selector(onItemClicked);

    // Restore frame position
    [self.window setFrameUsingName:@"FindFrame"];
}

- (void) showWindow:(id)sender {
	// Standard behaviour
	[super showWindow: sender];
	
    self.window.collectionBehavior = (NSWindowCollectionBehavior) (NSWindowCollectionBehaviorMoveToActiveSpace | NSWindowCollectionBehaviorTransient);
    
	// Set the first responder
	[self.window makeFirstResponder: findPhrase];
}

#pragma mark - 'Find all'
- (CGFloat) heightToFitResults {
    // Calculate new height of table based on the number of results we have.
    CGFloat newTableHeight = MIN(20,findAllResults.count) * (findAllTable.rowHeight+findAllTable.intercellSpacing.height);

    // Hieght of window = height of everything else + height of table
    return borders + newTableHeight;                 // Calculate new height of window
}

- (void) resizeToFitResults {
    CGFloat newHeight = [self heightToFitResults];              // Calculate new window height required
    NSRect windowFrame = self.window.frame;                     // Get current height of window
    CGFloat delta = newHeight - windowFrame.size.height;        // Find out the difference
    windowFrame.origin.y -= delta;                              // Adjust the window origin so the top-left of the window remains in the same place
    windowFrame.size.height = newHeight;                        // Adjust to the new height
    [self.window setFrame:windowFrame display:YES animate:NO];  // Set the window frame
}


- (void) updateFindAllResults {
	// Show nothing if there are no results in the find view
	if (findAllResults.count <= 0) {
		[self showAuxiliaryView: foundNothingView];
		return;
	}

	// Refresh the table
	[findAllTable reloadData];

    // Compose the results count message
    NSString* message;
    if( findAllResults.count == 1 ) {
        message = [IFUtility localizedString: @"Found Result Count"];
    } else {
        message = [IFUtility localizedString: @"Found Results Count"];
        message = [NSString stringWithFormat:message, findAllResults.count];
    }
    findCountText.stringValue = message;

    // Show the find all view
	[self showAuxiliaryView: findAllView];

    // Resize window to fit the number of results
    [self resizeToFitResults];
}

- (NSView*) findAllView {
	return findAllView;
}

- (IBAction) findAll: (id) sender {
	if (![self canFindAll]) {
		return;
	}

	// Add the find phrase to the history
	lastSearch = [findPhrase.stringValue copy];
	[self addPhraseToFindHistory: findPhrase.stringValue];

	// Load a new 'find all' view
	replaceAll.enabled = [self canReplaceAll];
	
	// Create a new find identifier
	findAllCount++;
	findIdentifier = @(findAllCount);
	
	// Clear out the find results
	findAllResults = [[NSMutableArray alloc] init];
	
	// Perform the initial find
	NSArray* findResults = [activeDelegate findAllMatches: findPhrase.stringValue
												   ofType: [self currentFindType]
                                               inLocation: IFFindCurrentPage
										 inFindController: self
										   withIdentifier: findIdentifier];
	if (findResults) {
		[findAllResults addObjectsFromArray: findResults];
	}
	
	[self updateFindAllResults];
}

#pragma mark - Performing 'replace all'

- (IBAction) replaceAll: (id) sender {
	if (![self canReplaceAll]) {
		return;
	}

    [self findAll:sender];
    
	// Store the replace phrase in the replacement history
	[self addPhraseToFindHistory: replacePhrase.stringValue];

	// Indicate that a 'replace all' operation is starting
	if ([activeDelegate respondsToSelector: @selector(beginReplaceAll:)]) {
		[activeDelegate beginReplaceAll: self];
	}
	
	// Get the replacement string
	NSString* replacement = replacePhrase.stringValue;
	
	// Replace each match in turn
	int x;
	int offset = 0;
	for (x=0; x<findAllResults.count; x++) {
		IFFindResult* thisResult = findAllResults[x];

        NSString* actualReplacement;
        
        if( ([self currentFindType] & 0xff) == IFFindRegexp ) {
            // Insert the group values into the replacement string instead of \1 \2 \3 etc...
            actualReplacement = [thisResult stringByReplacingGroups:replacement];
        }
        else {
            actualReplacement = replacement;
        }

		IFFindResult* newResult = [activeDelegate replaceFindAllResult: thisResult
															withString: actualReplacement
																offset: &offset];
		if (newResult == nil) {
			[thisResult setError: YES];
		} else {
			findAllResults[x] = newResult;
		}
	}

	// Finished
	if ([activeDelegate respondsToSelector: @selector(finishedReplaceAll:)]) {
		[activeDelegate finishedReplaceAll: self];
	}
	
	// Update the table with the new results
	[findAllTable reloadData];
	[findAllTable setNeedsDisplay: YES];
}


#pragma mark - The find all table

- (int)numberOfRowsInTableView: (NSTableView*) aTableView {
	return (int) findAllResults.count;
}

- (id)				tableView: (NSTableView*) aTableView 
	objectValueForTableColumn: (NSTableColumn*) aTableColumn
					row: (int) rowIndex {
    if( rowIndex >= findAllResults.count ) {
        return nil;
    }

	IFFindResult* row = findAllResults[rowIndex];
	return row.attributedContext;
}

- (void) onItemClicked {
    NSInteger clickedRow = findAllTable.clickedRow;

    if (clickedRow >= 0)
    {
        if (activeDelegate && [activeDelegate respondsToSelector: @selector(highlightFindResult:)]) {
            [activeDelegate highlightFindResult: findAllResults[clickedRow]];
        }
    }
}

- (void)tableViewSelectionDidChange: (NSNotification *)aNotification {
    if (findAllTable.numberOfSelectedRows != 1) return;

    NSUInteger selectedRow = findAllTable.selectedRow;
    if (activeDelegate && [activeDelegate respondsToSelector: @selector(highlightFindResult:)]) {
        [activeDelegate highlightFindResult: findAllResults[selectedRow]];
    }
}

- (BOOL)                        tableView:(NSTableView *)tableView
    shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn
                                      row:(NSInteger)row {
    // Turn off expansion tooltips
    return NO;
}

#pragma mark - Find/replace history

- (id)				 comboBox: (NSComboBox*)	aComboBox
	objectValueForItemAtIndex: (int)			index {
	// Choose the history list that's being displayed in the specified combo box
	NSMutableArray* itemArray = nil;
	if (aComboBox == findPhrase) {
		itemArray = findHistory;
	} else if (aComboBox == replacePhrase) {
		itemArray = replaceHistory;
	}
	
	// Return the item
	if (!itemArray || index < 0 || index >= itemArray.count) {
		return nil;
	} else {
		return itemArray[index];
	}
}

- (int) numberOfItemsInComboBox: (NSComboBox *)	aComboBox {
	// Choose the history list that's being displayed in the specified combo box
	NSMutableArray* itemArray = nil;
	if (aComboBox == findPhrase) {
		itemArray = findHistory;
	} else if (aComboBox == replacePhrase) {
		itemArray = replaceHistory;
	}
	
	// Return the number of items
	if (!itemArray) {
		return 0;
	} else {
		return (int) itemArray.count;
	}
}

#pragma mark - The auxiliary view

- (void) showAuxiliaryView: (NSView*) newAuxView {
	// Do nothing if the aux view hasn't changed
	if (newAuxView == auxView) return;
	
	// Hide the old auxiliary view
	if (auxView) {
        [auxView removeFromSuperview];
		auxView = nil;
	}
	
	// Show the new auxiliary view
	NSRect auxFrame		= NSMakeRect(0,0,0,0);
	
	if (newAuxView) {
		// Remember this view
		auxFrame	= newAuxView.frame;
		
		// Set its size
		auxFrame.origin		= NSMakePoint(0, auxViewPanel.frame.size.height-auxFrame.size.height);
		auxFrame.size.width = self.window.contentView.frame.size.width;
		newAuxView.frame = auxFrame;
	}
	
	// Resize the window
	NSRect currentWinFrame = self.window.frame;
    
    CGFloat newWindowHeight = (winFrame.size.height + auxFrame.size.height);
    
    CGFloat heightDiff = newWindowHeight - currentWinFrame.size.height;
	currentWinFrame.size.height += heightDiff;
	currentWinFrame.origin.y	-= heightDiff;
    
    [self.window setFrame:currentWinFrame display:YES];
	
	// Add the new view
	if (newAuxView) {
		auxView		= newAuxView;
        
		auxFrame.origin		= NSMakePoint(0, auxViewPanel.frame.size.height-auxFrame.size.height);
		auxFrame.size.width = self.window.contentView.frame.size.width;
		newAuxView.frame = auxFrame;

        [newAuxView removeFromSuperview];
        [auxViewPanel addSubview:newAuxView];
	}
}

#pragma mark - Combo box delegate methods

- (void) comboBoxEnterKeyPress: (id) sender {
	if (sender == findPhrase) {
        // Pressing return in the findPhrase combo box will close the find window.
		[self findNext: self];
		[self.window orderOut: self];
	} else if (sender == replacePhrase) {
		[self findNext: self];
	} else {
		[self findNext: self];
	}
}

- (void)controlTextDidChange:(NSNotification *)aNotification {
    if( aNotification.object == findPhrase ) {
        [self updateControls: NO];
    }
}

#pragma mark - Window delegate methods

- (void) windowWillClose: (NSNotification*) notification {
    NSWindow *win = notification.object;
    
    if( win == self.window ) {
        // Clear the find all results
        [findAllResults removeAllObjects];
        [self showAuxiliaryView: nil];
        [self.window saveFrameUsingName:@"FindFrame"];
    }
}

@end
