//
//  IFDocumentationPage.h
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <Cocoa/Cocoa.h>
#import "IFPage.h"

//
// The 'documentation' page
//
@interface IFDocumentationPage : IFPage<WebFrameLoadDelegate, WebResourceLoadDelegate>

// The documentation view
- (void) openURL: (NSURL*) url;							// Tells the documentation view to open a specific URL
- (IBAction) showToc: (id) sender;						// Opens the table of contents

- (instancetype) initWithProjectController: (IFProjectController*) controller;

@end
