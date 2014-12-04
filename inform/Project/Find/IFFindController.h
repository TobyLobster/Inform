//
//  IFFindController.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 05/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFFindResult.h"

///
/// Controller for the find window
///
@interface IFFindController : NSWindowController {
	// The components of the find dialog
	IBOutlet NSComboBox*	findPhrase;									// The phrase to search for
	IBOutlet NSComboBox*	replacePhrase;								// The phrase to replace it with

	// Ignore case radio button
	IBOutlet NSButton*		ignoreCase;									// The 'ignore case' checkbox

    // Pull down menu of how to search
	IBOutlet NSPopUpButton* searchType;									// The 'contains/begins with/complete word/regexp' pop-up button
	IBOutlet NSMenuItem*	containsItem;								// Choices for the type of object to find
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
	IBOutlet NSProgressIndicator* findProgress;							// The 'searching' progress indicator
    
    // Parent view to position extra content
	IBOutlet NSView*		auxViewPanel;								// The auxilary view panel
	
	// The regular expression help view
	IBOutlet NSView*		regexpHelpView;								// The view containing information about regexps
	
	// The 'find all' views
	IBOutlet NSView*		foundNothingView;							// The view to show if we don't find any matches
	IBOutlet NSView*		findAllView;								// The main 'find all' view
	IBOutlet NSTableView*	findAllTable;								// The 'find all' results table
    IBOutlet NSTextField*   findCountText;                              // Text of how many results we have
    float                   borders;                                    // Height of the window with the find all view open, but without the results table. A constant.
	
	// Things we've searched for
	NSMutableArray*			replaceHistory;								// The 'replace' history
	NSMutableArray*			findHistory;								// The 'find' history
	NSString*				lastSearch;									// The last phrase that was searched for

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
	id activeDelegate;													// The delegate that we've chosen to work with
}

// Initialisation

+ (IFFindController*) sharedFindController;								// The shared find window controller

// Actions
- (IBAction) findNext: (id) sender;										// 'Next' clicked
- (IBAction) findPrevious: (id) sender;									// 'Previous' clicked
- (IBAction) replaceAndFind: (id) sender;								// 'Replace and find' clicked
- (IBAction) replace: (id) sender;										// 'Replace' clicked
- (IBAction) findAll: (id) sender;										// 'Find all' clicked
- (IBAction) replaceAll: (id) sender;									// 'Replace all' clicked
- (IBAction) useSelectionForFind: (id) sender;							// 'Use selection for find' chosen from the menu
- (IBAction) findTypeChanged: (id) sender;								// The user has selected a new type of find (from contains, etc)
- (IBAction) comboBoxEnterKeyPress: (id) sender;						// The user hit enter in the 'find all' combo box


// Menu actions
- (BOOL) canFindAgain: (id) sender;										// YES if find next/previous can be sensibly repeated
- (BOOL) canUseSelectionForFind: (id) sender;							// YES if 'useSelectionForFind' will work

// Updating the find window
- (void) updateFromFirstResponder;										// Updates the status of the find window from the first responder

- (void) showAuxiliaryView: (NSView*) auxView;							// Shows the specified auxiliary view in the find window

@end

///
/// Delegate methods that can be used to enhance the find dialog (or provide it for new views or controllers)
///
@interface NSObject(IFFindDelegate)

// Basic interface (all searchable objects must implement this)
- (BOOL) findNextMatch:	(NSString*) match								// Request to find the next match
				ofType: (IFFindType) type;
- (BOOL) findPreviousMatch: (NSString*) match							// Request to find the previous match
					ofType: (IFFindType) type;

- (BOOL) canUseFindType: (IFFindType) find;								// Allows delegates to specify which type of file they can search on

- (NSString*) currentSelectionForFind;									// Returns whatever was currently selected: used to implement the 'use selection for find' menu option

// 'Find all'
- (NSArray*) findAllMatches: (NSString*) match							// Should return an array of IFFindResults
					 ofType: (IFFindType) type
                 inLocation: (IFFindLocation) location
		   inFindController: (IFFindController*) controller
			 withIdentifier: (id) identifier;
- (void) highlightFindResult: (IFFindResult*) result;					// The user has selected a find result, which should now be displayed

// Replace
- (void) replaceFoundWith: (NSString*) match;							// Should replace the last found item with the specified text (or the currently selected item, if the user has manually changed the selection)
- (void) beginReplaceAll: (IFFindController*) sender;					// Indicates that a replace all operation is starting
- (IFFindResult*) replaceFindAllResult: (IFFindResult*) result			// Request to replace a find all result as part of a replace all operation
							withString: (NSString*) replacement
								offset: (int*) offset;
- (void) finishedReplaceAll: (IFFindController*) sender;				// The replace all operation has finished
- (NSArray*) lastFoundGroups;                                           // returns an array of the groups found on the last regex search. Used in "Replace and Find" and "Replace"

@end
