//
//  IFFindController.h
//  Inform
//
//  Created by Andrew Hunter on 05/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFFindResult.h"

///
/// Controller for the find window
///
@interface IFFindController : NSWindowController

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

@property (atomic, readonly, copy) NSString *currentSelectionForFind;	// Returns whatever was currently selected: used to implement the 'use selection for find' menu option

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
@property (atomic, readonly, copy) NSArray *lastFoundGroups;            // returns an array of the groups found on the last regex search. Used in "Replace and Find" and "Replace"

@end
