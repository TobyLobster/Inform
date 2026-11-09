//
//  IFFindInFilesController.h
//  Inform
//
//  Created by Andrew Hunter on 05/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFFindResult.h"
#import "Inform-Swift.h"

NS_ASSUME_NONNULL_BEGIN

@class IFProject;
@class IFFindInFiles;
@class IFProjectController;

///
/// Controller for the find window
///
@interface IFFindInFilesController : NSWindowController <IFFindClickableTableViewDelegate, NSControlTextEditingDelegate>

// Initialisation

/// The shared find window controller
+ (IFFindInFilesController*) sharedFindInFilesController;

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

@end

NS_ASSUME_NONNULL_END
