//
//  IFWelcomeWindow.h
//  Inform
//
//  Created by Andrew Hunter on 05/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IFWelcomeWindow : NSWindowController<NSTableViewDelegate, NSTableViewDataSource>

+ (IFWelcomeWindow*) sharedWelcomeWindow;				// Gets the shared welcome window
+ (void) hideWelcomeWindow;								// Hide the welcome window
+ (void) showWelcomeWindow;                             // Show the welcome window
- (void) hideWebView;
- (void) showWebView;

- (IBAction) clickImage:(id) sender;

@end
