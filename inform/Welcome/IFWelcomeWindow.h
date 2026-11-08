//
//  IFWelcomeWindow.h
//  Inform
//
//  Created by Andrew Hunter on 05/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface IFWelcomeWindow : NSWindowController<NSTableViewDelegate, NSTableViewDataSource, WKNavigationDelegate>

/// Gets the shared welcome window
+ (IFWelcomeWindow*) sharedWelcomeWindow;
/// Hide the welcome window
+ (void) hideWelcomeWindow;
/// Show the welcome window
+ (void) showWelcomeWindow;

- (void) hideWebView;
- (void) showWebView;

/// The news page for the given news, which has a line for each event: its start date, its end date, its
/// headline and its link, separated by tabs. Nil if the page's template can't be read.
- (nullable NSString*) newsPageForNews: (nullable NSString*) latestNews;

- (IBAction) clickImage:(nullable id) sender;

@end

NS_ASSUME_NONNULL_END
