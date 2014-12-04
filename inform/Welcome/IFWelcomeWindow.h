//
//  IFWelcomeWindow.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 05/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface IFWelcomeWindow : NSWindowController<NSTableViewDelegate, NSTableViewDataSource> {
	IBOutlet NSProgressIndicator*   backgroundProgress;         // Progress indicator that shows when a background process is running
    IBOutlet NSScrollView*          recentDocumentsScrollView;  // Recent document scroll view
    IBOutlet NSTableView*           recentDocumentsTableView;   // Recent document Table View
    IBOutlet NSScrollView*          createDocumentsScrollView;  // Create document scroll view
    IBOutlet NSTableView*           createDocumentsTableView;   // Create document Table View
    IBOutlet NSScrollView*          sampleDocumentsScrollView;  // Sample document scroll view
    IBOutlet NSTableView*           sampleDocumentsTableView;   // Sample document Table View
    IBOutlet NSView*                parentView;                 // Parent
    IBOutlet WebView*               webView;                    // Show a web page (for advice)
    IBOutlet NSView*                middleView;                 // Show the middle section
    IBOutlet NSButton*              imageButton;                // Top banner image, as a button

    NSMutableArray*                 recentInfoArray;            // Array of recent file info
    NSMutableArray*                 createInfoArray;            // Array of create file info
    NSMutableArray*                 sampleInfoArray;            // Array of sample file info
}

+ (IFWelcomeWindow*) sharedWelcomeWindow;				// Gets the shared welcome window
+ (void) hideWelcomeWindow;								// Hide the welcome window
+ (void) showWelcomeWindow;                             // Show the welcome window
- (void) hideWebView;
- (void) showWebView;

- (IBAction) clickImage:(id) sender;

@end
