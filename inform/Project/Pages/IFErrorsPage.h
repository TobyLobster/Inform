//
//  IFErrorsPage.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFPage.h"
#import "IFCompilerController.h"

//
// The 'errors' page
//
@interface IFErrorsPage : IFPage {
    IBOutlet IFCompilerController* compilerController;		// The compiler controller object
	
	NSMutableArray* pageCells;								// Cells used to select the pages in the compiler controller
}

// Getting information about this page
- (IFCompilerController*) compilerController;				// The compiler controller for this page

- (id) initWithProjectController: (IFProjectController*) controller;

@end
