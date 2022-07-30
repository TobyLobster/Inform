//
//  IFWelcomeWindow.h
//  Inform
//
//  Created by Andrew Hunter on 05/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface IFWelcomeWindow : NSWindowController<NSTableViewDelegate, NSTableViewDataSource, WKNavigationDelegate>

/// Gets the shared welcome window
+ (IFWelcomeWindow*) sharedWelcomeWindow;
/// Hide the welcome window
+ (void) hideWelcomeWindow;
/// Show the welcome window
+ (void) showWelcomeWindow;

- (void) hideWebView;
- (void) showWebView;

- (IBAction) clickImage:(id) sender;

@end
