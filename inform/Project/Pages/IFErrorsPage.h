//
//  IFErrorsPage.h
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFCompilerController.h"

#import "IFPage.h"

NS_ASSUME_NONNULL_BEGIN

@class IFCompilerController;

///
/// The 'errors' page, the delegate of its compiler controller (which its nib connects), and so of the
/// controller's web views' navigation
///
@interface IFErrorsPage : IFPage<IFCompilerControllerDelegate>

// Getting information about this page
/// The compiler controller for this page
@property (atomic, readonly, strong) IBOutlet IFCompilerController *compilerController;

// The history
/// Switches to this page, and its compiler controller to a tab, as the page records in the history
- (void) switchToPageWithTabId: (IFCompilerTabId) tabId;
/// Opens a URL from the history in the compiler controller's current web view, without recording it in the history
/// again
- (void) openHistoricalURL: (nullable NSURL*) url;

- (instancetype) initWithProjectController: (IFProjectController*) controller
                                  withPane: (IFProjectPane*) pane NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
