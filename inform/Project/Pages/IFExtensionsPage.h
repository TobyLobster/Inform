//
//  IFExtensionsPage.h
//  Inform
//
//  Created by Toby Nelson on 09/02/2014.
//

#import <WebKit/WebKit.h>
#import <Cocoa/Cocoa.h>
#import "IFPage.h"

//
// The 'extensions' page
//
@interface IFExtensionsPage : IFPage<WebResourceLoadDelegate, WebFrameLoadDelegate>

// The documentation view
- (void) openURL: (NSURL*) url;							// Tells the view to open a specific URL
- (IBAction) showHome: (id) sender;						// Opens the home page
- (void) extensionUpdated:(NSString*) javascriptId;

- (instancetype) initWithProjectController: (IFProjectController*) controller;

@end
