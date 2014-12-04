//
//  IFIsSkein.h
//  Inform
//
//  Created by Andrew Hunter on Mon Jul 05 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import "IFInspector.h"
#import "IFProject.h"
#import "IFProjectController.h"

#import "ZoomView/ZoomSkein.h"
#import "ZoomView/ZoomSkeinView.h"

extern NSString* IFIsSkeinInspector;

//
// The skein inspector
//
@interface IFIsSkein : IFInspector {
	NSWindow* activeWin;								// The currently active window
	IFProject* activeProject;							// The currently active project
	IFProjectController* activeController;				// The currently active window controller, if a ProjectController
	
	IBOutlet ZoomSkeinView* skeinView;					// The view we'll be displaying the skein in
}

+ (IFIsSkein*) sharedIFIsSkein;							// The shared skein inspector

@end
