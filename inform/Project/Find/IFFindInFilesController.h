//
//  IFFindInFilesController.h
//  Inform
//
//  Created by Andrew Hunter on 05/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFFindResult.h"

NS_ASSUME_NONNULL_BEGIN

@class IFProject;
@class IFFindInFiles;
@class IFProjectController;

///
/// Controller for the find window
///
@interface IFFindInFilesController : NSWindowController <NSControlTextEditingDelegate>

// Initialisation

/// The shared find window controller, which keeps its find history in the user's defaults
+ (IFFindInFilesController*) sharedFindInFilesController;
/// A find window controller that keeps its find history in the given defaults
- (instancetype) initWithDefaults: (NSUserDefaults*) defaults;

/// Set the project to use for the current search
-(void) setProject: (IFProject*) aProject;
- (void) setController: (IFProjectController*) aController;

// Actions
/// 'Find all' clicked
- (IBAction) findAll: (nullable id) sender;
/// The user has selected a new type of find (from contains, etc)
- (IBAction) findTypeChanged: (nullable id) sender;
/// The user hit enter in the 'find' combo box
- (IBAction) comboBoxEnterKeyPress: (nullable id) sender;

- (void) showFindInFilesWindow: (IFProjectController*) aController;     //
- (void) startFindInFilesSearchWithPhrase: (NSString*) aPhrase
                         withLocationType: (IFFindLocation) aLocationType
                                 withType: (IFFindType) aType;

/// A row of the results was clicked (IFFindClickableTableViewDelegate, which the class adopts in its implementation,
/// as the protocol is in Swift)
- (void)tableView: (NSTableView *)tableView
      didClickRow: (NSInteger)rowIndex;

@end

NS_ASSUME_NONNULL_END
