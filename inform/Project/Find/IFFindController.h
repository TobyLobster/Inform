//
//  IFFindController.h
//  Inform
//
//  Created by Andrew Hunter on 05/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFFindResult.h"

NS_ASSUME_NONNULL_BEGIN

///
/// Controller for the find window
///
@interface IFFindController : NSWindowController <NSControlTextEditingDelegate>

// Initialisation

+ (IFFindController*) sharedFindController;								// The shared find window controller, which keeps its histories in the user's defaults
- (instancetype) initWithDefaults: (NSUserDefaults*) defaults;			// A find window controller that keeps its find and replace histories in the given defaults

// Actions
- (IBAction) findNext: (nullable id) sender;							// 'Next' clicked
- (IBAction) findPrevious: (nullable id) sender;						// 'Previous' clicked
- (IBAction) replaceAndFind: (nullable id) sender;						// 'Replace and find' clicked
- (IBAction) replace: (nullable id) sender;								// 'Replace' clicked
- (IBAction) findAll: (nullable id) sender;								// 'Find all' clicked
- (IBAction) replaceAll: (nullable id) sender;							// 'Replace all' clicked
- (IBAction) useSelectionForFind: (nullable id) sender;					// 'Use selection for find' chosen from the menu
- (IBAction) findTypeChanged: (nullable id) sender;						// The user has selected a new type of find (from contains, etc)
- (IBAction) comboBoxEnterKeyPress: (nullable id) sender;				// The user hit enter in the 'find all' combo box

// Updating the find window
- (void) updateFromFirstResponder;										// Updates the status of the find window from the first responder

@end

///
/// Delegate methods that can be used to enhance the find dialog (or provide it for new views or controllers)
///
@protocol IFFindDelegate <NSObject>

// Basic interface (all searchable objects must implement this)
/// Request to find the next match
- (void) findNextMatch:	(NSString*) match
				ofType: (IFFindType) type
     completionHandler: (nullable void (^)(bool result))completionHandler;
@optional

/// Request to find the previous match
- (void) findPreviousMatch: (NSString*) match
					ofType: (IFFindType) type
         completionHandler: (nullable void (^)(bool result))completionHandler;

/// Allows delegates to specify which type of file they can search on
- (BOOL) canUseFindType: (IFFindType) find;

/// Returns whatever was currently selected (or nil if it can't be had): used to implement the 'use selection for find' menu option
- (void) currentSelectionForFindWithCompletionHandler:(void (^)(NSString* _Nullable result))completionHandler;

// 'Find all'
/// Should return an array of IFFindResults (nil if there's nothing to find)
- (nullable NSArray<IFFindResult*>*) findAllMatches: (NSString*) match
                                    ofType: (IFFindType) type
                                inLocation: (IFFindLocation) location
                          inFindController: (IFFindController*) controller
                            withIdentifier: (id) identifier;
/// The user has selected a find result, which should now be displayed
- (void) highlightFindResult: (IFFindResult*) result;

// Replace
/// Should replace the last found item with the specified text (or the currently selected item, if the user has manually changed the selection)
- (void) replaceFoundWith: (NSString*) match;
/// Indicates that a replace all operation is starting
- (void) beginReplaceAll: (IFFindController*) sender;
/// Request to replace a find all result as part of a replace all operation (nil if its text has changed)
- (nullable IFFindResult*) replaceFindAllResult: (IFFindResult*) result
							withString: (NSString*) replacement
								offset: (int*) offset;
/// The replace all operation has finished
- (void) finishedReplaceAll: (IFFindController*) sender;
/// returns an array of the groups found on the last regex search. Used in "Replace and Find" and "Replace"
@property (atomic, readonly, copy, nullable) NSArray<NSString*> *lastFoundGroups;

@end

NS_ASSUME_NONNULL_END
