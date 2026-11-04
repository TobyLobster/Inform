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

@class IFCompilerController;

///
/// The 'errors' page
///
@interface IFErrorsPage : IFPage<WKNavigationDelegate>

// Getting information about this page
/// The compiler controller for this page
@property (atomic, readonly, strong) IBOutlet IFCompilerController *compilerController;

- (instancetype) initWithProjectController: (IFProjectController*) controller
                                  withPane: (IFProjectPane*) pane NS_DESIGNATED_INITIALIZER;

@end
